#include "cuda_runtime.h"
#include "curand.h"
#include "cublas_v2.h"

extern "C" {
#include "convolutional_layer.h"
#include "batchnorm_layer.h"
#include "gemm.h"
#include "blas.h"
#include "im2col.h"
#include "col2im.h"
#include "utils.h"
#include "cuda.h"
}

__global__ void binarize_kernel(float *x, int n, float *binary)
{
    int i = (blockIdx.x + blockIdx.y * gridDim.x) * blockDim.x + threadIdx.x;
    if (i >= n)
        return;
    binary[i] = (x[i] >= 0) ? 1 : -1;
}

void binarize_gpu(float *x, int n, float *binary)
{
    binarize_kernel<<<cuda_gridsize(n), BLOCK>>>(x, n, binary);
    check_error(cudaPeekAtLastError());
}

__global__ void binarize_input_kernel(float *input, int n, int size, float *binary)
{
    int s = (blockIdx.x + blockIdx.y * gridDim.x) * blockDim.x + threadIdx.x;
    if (s >= size)
        return;
    int i = 0;
    float mean = 0;
    for (i = 0; i < n; ++i)
    {
        mean += abs(input[i * size + s]);
    }
    mean = mean / n;
    for (i = 0; i < n; ++i)
    {
        binary[i * size + s] = (input[i * size + s] > 0) ? mean : -mean;
    }
}

void binarize_input_gpu(float *input, int n, int size, float *binary)
{
    binarize_input_kernel<<<cuda_gridsize(size), BLOCK>>>(input, n, size, binary);
    check_error(cudaPeekAtLastError());
}

__global__ void binarize_weights_kernel(float *weights, int n, int size, float *binary)
{
    int f = (blockIdx.x + blockIdx.y * gridDim.x) * blockDim.x + threadIdx.x;
    if (f >= n)
        return;
    int i = 0;
    float mean = 0;
    for (i = 0; i < size; ++i)
    {
        mean += abs(weights[f * size + i]);
    }
    mean = mean / size;
    for (i = 0; i < size; ++i)
    {
        binary[f * size + i] = (weights[f * size + i] > 0) ? mean : -mean;
        //binary[f*size + i] = weights[f*size + i];
    }
}

void binarize_weights_gpu(float *weights, int n, int size, float *binary)
{
    binarize_weights_kernel<<<cuda_gridsize(n), BLOCK>>>(weights, n, size, binary);
    check_error(cudaPeekAtLastError());
}

void forward_convolutional_layer_gpu(convolutional_layer l, network net)
{
    fill_gpu(l.outputs * l.batch, 0, l.output_gpu, 1);
    if (l.binary)
    {
        binarize_weights_gpu(l.weights_gpu, l.n, l.c * l.size * l.size, l.binary_weights_gpu);
        swap_binary(&l);
    }

    if (l.xnor)
    {
        binarize_weights_gpu(l.weights_gpu, l.n, l.c * l.size * l.size, l.binary_weights_gpu);
        swap_binary(&l);
        binarize_gpu(net.input_gpu, l.c * l.h * l.w * l.batch, l.binary_input_gpu);
        net.input_gpu = l.binary_input_gpu;
    }

#ifdef CUDNN
    float one = 1;
    cudnnStatus_t status = cudnnConvolutionForward(cudnn_handle(),
                            &one,
                            l.srcTensorDesc,
                            net.input_gpu,
                            l.weightDesc,
                            l.weights_gpu,
                            l.convDesc,
                            l.fw_algo,
                            net.workspace,
                            l.workspace_size,
                            &one,
                            l.dstTensorDesc,
                            l.output_gpu);
    checkCUDNN(status);
    //printf("\nfilter layer %d:\n", net.index);
#else

    int m = l.n;                   // output channel
    int k = l.size * l.size * l.c; // kernel size, input channel
    int n = l.out_h * l.out_w;     // output size

    float *a = l.weights_gpu;
    float *c = l.output_gpu;

    int group_size = l.c / l.groups;
    int group_step = l.h * l.w * group_size;
    k = k / l.groups;
    m = m / l.groups;
    int i, j;
    for (i = 0; i < l.batch; ++i)
    {
        for (j = 0; j < l.groups; j++)
        {
            float *aoffset = a + j * k;
            float *boffset = net.workspace;
            float *coffset = c + j * n * group_size;
            float *inputoffset = net.input_gpu + group_step * j;
            im2col_gpu(inputoffset, group_size, l.h, l.w, l.size, l.stride, l.pad, boffset);
            gemm_gpu(0, 0, m, n, k, 1, aoffset, k, boffset, n, 1, coffset, n);
        }

        c += l.out_h * l.out_w * l.n;
        net.input_gpu += l.c * l.h * l.w;
    }
#endif
//    cuda_pull_array(l.output_gpu, l.output, l.batch * l.outputs);
//    image im=float_to_image(l.out_w, l.out_h, l.n, l.output);
//    printf("\nfilter layer %d:\n", net.index);
//    print_image(im);
//    cuda_pull_array(l.output_gpu, l.output, l.batch * l.outputs);
//    image im = float_to_image(l.out_w, l.out_h, l.n, l.output);
//    printf("\nfilter laryer %d:\n", l.index);
//    print_image(im);
    
    if (l.batch_normalize)
    {
        forward_batchnorm_layer_gpu(l, net);
    }
    else
    {
        add_bias_gpu(l.output_gpu, l.biases_gpu, l.batch, l.n, l.out_w * l.out_h);
    }

    activate_array_gpu(l.output_gpu, l.outputs * l.batch, l.activation);
    //if(l.dot > 0) dot_error_gpu(l);
    if (l.binary || l.xnor)
        swap_binary(&l);
}

__global__ void smooth_kernel(float *x, int n, int w, int h, int c, int size, float rate, float *delta)
{
    int id = (blockIdx.x + blockIdx.y * gridDim.x) * blockDim.x + threadIdx.x;
    if (id >= n)
        return;

    int j = id % w;
    id /= w;
    int i = id % h;
    id /= h;
    int k = id % c;
    id /= c;
    int b = id;

    int w_offset = -(size / 2.);
    int h_offset = -(size / 2.);

    int out_index = j + w * (i + h * (k + c * b));
    int l, m;
    for (l = 0; l < size; ++l)
    {
        for (m = 0; m < size; ++m)
        {
            int cur_h = h_offset + i + l;
            int cur_w = w_offset + j + m;
            int index = cur_w + w * (cur_h + h * (k + b * c));
            int valid = (cur_h >= 0 && cur_h < h &&
                         cur_w >= 0 && cur_w < w);
            delta[out_index] += valid ? rate * (x[index] - x[out_index]) : 0;
        }
    }
}

extern "C" void smooth_layer(layer l, int size, float rate)
{
    int h = l.out_h;
    int w = l.out_w;
    int c = l.out_c;

    size_t n = h * w * c * l.batch;

    smooth_kernel<<<cuda_gridsize(n), BLOCK>>>(l.output_gpu, n, l.w, l.h, l.c, size, rate, l.delta_gpu);
    check_error(cudaPeekAtLastError());
}

void backward_convolutional_layer_gpu(convolutional_layer l, network net)
{
    if (l.smooth)
    {
        smooth_layer(l, 5, l.smooth);
    }
    constrain_gpu(l.outputs * l.batch, 1, l.delta_gpu, 1);
    gradient_array_gpu(l.output_gpu, l.outputs * l.batch, l.activation, l.delta_gpu);

    if (l.batch_normalize)
    {
        backward_batchnorm_layer_gpu(l, net);
    }
    else
    {
        backward_bias_gpu(l.bias_updates_gpu, l.delta_gpu, l.batch, l.n, l.out_w * l.out_h);
    }
    float *original_input = net.input_gpu;

    if (l.xnor)
        net.input_gpu = l.binary_input_gpu;
#ifdef CUDNN
    float one = 1;
    cudnnConvolutionBackwardFilter(cudnn_handle(),
                                   &one,
                                   l.srcTensorDesc,
                                   net.input_gpu,
                                   l.ddstTensorDesc,
                                   l.delta_gpu,
                                   l.convDesc,
                                   l.bf_algo,
                                   net.workspace,
                                   l.workspace_size,
                                   &one,
                                   l.dweightDesc,
                                   l.weight_updates_gpu);

    if (net.delta_gpu)
    {
        if (l.binary || l.xnor)
            swap_binary(&l);
        cudnnConvolutionBackwardData(cudnn_handle(),
                                     &one,
                                     l.weightDesc,
                                     l.weights_gpu,
                                     l.ddstTensorDesc,
                                     l.delta_gpu,
                                     l.convDesc,
                                     l.bd_algo,
                                     net.workspace,
                                     l.workspace_size,
                                     &one,
                                     l.dsrcTensorDesc,
                                     net.delta_gpu);
        if (l.binary || l.xnor)
            swap_binary(&l);
        if (l.xnor)
            gradient_array_gpu(original_input, l.batch * l.c * l.h * l.w, HARDTAN, net.delta_gpu);
    }

#else
    int i, j;
    int m = l.n;
    int n = l.size * l.size * l.c;
    int k = l.out_w * l.out_h;

    int group_size = l.c / l.groups;
    int group_step = l.h * l.w * group_size;
    n = n / l.groups;
    m = m / l.groups;
    for (i = 0; i < l.batch; ++i)
    {
        float *input_data = net.input_gpu + i * l.c * l.h * l.w;
        float *deltas = l.delta_gpu + i * l.n * l.out_w * l.out_h;
        float *outdeltas = net.delta_gpu + i * l.c * l.w *l.h;
        for (j = 0; j < l.groups; j++)
        {
            float *im = input_data + j * group_step;
            float *aoffset = deltas + j * group_size * k;
            float *boffset = net.workspace;
            float *coffset = l.weight_updates_gpu + j * n;

            im2col_gpu(im, group_size, l.h, l.w, l.size, l.stride, l.pad, boffset);
            gemm_gpu(0, 1, m, n, k, 1, aoffset, k, boffset, k, 1, coffset, n);

            if (net.delta_gpu)
            {
                if(l.binary || l.xnor) swap_binary(&l);
                aoffset = l.weights_gpu + j * n;
                boffset = deltas + j * group_size * k;
                coffset = net.workspace;

                gemm_gpu(1, 0, n, k, m, 1, aoffset, n, boffset, k, 0, coffset, k);
                col2im_gpu(net.workspace, group_size, l.h, l.w, l.size, l.stride, l.pad, outdeltas + j * group_step);
                if(l.binary || l.xnor) swap_binary(&l);
            }
        }

        if (net.delta_gpu && l.xnor)
        {
            gradient_array_gpu(original_input + i * l.c * l.h * l.w,
                               l.c * l.h * l.w,
                               HARDTAN,
                               net.delta_gpu + i * l.c * l.h * l.w);
        }
    }
#endif
}

void pull_convolutional_layer(convolutional_layer layer)
{
    cuda_pull_array(layer.weights_gpu, layer.weights, layer.c * layer.n * layer.size * layer.size);
    cuda_pull_array(layer.biases_gpu, layer.biases, layer.n);
    cuda_pull_array(layer.weight_updates_gpu, layer.weight_updates, layer.c * layer.n * layer.size * layer.size);
    cuda_pull_array(layer.bias_updates_gpu, layer.bias_updates, layer.n);
    if (layer.batch_normalize)
    {
        cuda_pull_array(layer.scales_gpu, layer.scales, layer.n);
        cuda_pull_array(layer.rolling_mean_gpu, layer.rolling_mean, layer.n);
        cuda_pull_array(layer.rolling_variance_gpu, layer.rolling_variance, layer.n);
    }
}

void push_convolutional_layer(convolutional_layer layer)
{
    cuda_push_array(layer.weights_gpu, layer.weights, layer.c * layer.n * layer.size * layer.size);
    cuda_push_array(layer.biases_gpu, layer.biases, layer.n);
    cuda_push_array(layer.weight_updates_gpu, layer.weight_updates, layer.c * layer.n * layer.size * layer.size);
    cuda_push_array(layer.bias_updates_gpu, layer.bias_updates, layer.n);
    if (layer.batch_normalize)
    {
        cuda_push_array(layer.scales_gpu, layer.scales, layer.n);
        cuda_push_array(layer.rolling_mean_gpu, layer.rolling_mean, layer.n);
        cuda_push_array(layer.rolling_variance_gpu, layer.rolling_variance, layer.n);
    }
}

void update_convolutional_layer_gpu(layer l, update_args a)
{
    float learning_rate = a.learning_rate * l.learning_rate_scale;
    float momentum = a.momentum;
    float decay = a.decay;
    int batch = a.batch;

    int size = l.size * l.size * l.c * l.n;

    if (a.adam)
    {
        adam_update_gpu(l.weights_gpu, l.weight_updates_gpu, l.m_gpu, l.v_gpu, a.B1, a.B2, a.eps, decay, learning_rate, size, batch, a.t);
        adam_update_gpu(l.biases_gpu, l.bias_updates_gpu, l.bias_m_gpu, l.bias_v_gpu, a.B1, a.B2, a.eps, decay, learning_rate, l.n, batch, a.t);
        if (l.scales_gpu)
        {
            adam_update_gpu(l.scales_gpu, l.scale_updates_gpu, l.scale_m_gpu, l.scale_v_gpu, a.B1, a.B2, a.eps, decay, learning_rate, l.n, batch, a.t);
        }
    }
    else
    {
        axpy_gpu(size, -decay * batch, l.weights_gpu, 1, l.weight_updates_gpu, 1);
        axpy_gpu(size, learning_rate / batch, l.weight_updates_gpu, 1, l.weights_gpu, 1);
        scal_gpu(size, momentum, l.weight_updates_gpu, 1);

        axpy_gpu(l.n, learning_rate / batch, l.bias_updates_gpu, 1, l.biases_gpu, 1);
        scal_gpu(l.n, momentum, l.bias_updates_gpu, 1);

        if (l.scales_gpu)
        {
            axpy_gpu(l.n, learning_rate / batch, l.scale_updates_gpu, 1, l.scales_gpu, 1);
            scal_gpu(l.n, momentum, l.scale_updates_gpu, 1);
        }
    }
}
