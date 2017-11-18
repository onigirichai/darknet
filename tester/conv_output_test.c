/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
#include <stdio.h>
#include "conv_output_test.h"
#include "../src/convolutional_layer.h"


void text_convolutional_output(){
    convolutional_layer l = make_convolutional_layer(1, 5, 5, 3, 1, 1, 1, 0, 1, LEAKY, 0, 0, 0, 0);
    
    float data[] = {
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
    };
    
    network net=make_network(1);
    net.h=5;
    net.w=5;
    net.c=3;
    net.workspace=calloc(1, l.workspace_size);
    //printf("\n%zd",l.workspace_size);
    net.batch=1;
    net.input=data;
    
    memset(l.output, 0, sizeof (float) * l.out_h * l.out_w * l.out_c);
    
        int h = l.out_h;
        int w = l.out_w;
        int c = l.n;

        
        image iw = float_to_image(l.size, l.c, l.n, l.weights);
        image ib = float_to_image(l.size, l.c, l.n, l.biases);
        printf("weights:\n");
        print_image(iw);
        printf("biases:\n");
        print_image(ib);
        
        forward_convolutional_layer(l ,net );
        
        image im = float_to_image(w, h, c, l.output);
        printf("3x3 filter:\n");
        print_image(im);
//        
//        backward_convolutional_layer(l ,net );
//        
//        im = float_to_image(w, h, c, l.output);
//        printf("3x3 filter:\n");
//        print_image(im);
        fflush(stderr);
}

int main(){
    text_convolutional_output();
}


//batch h w c;n size stride padding groups;Act bat_nor binary xnor adam
//void text_convolutional_output(){
//    convolutional_layer l = make_convolutional_layer(1, 5, 5, 3, 1, 1, 1, 0, 1, LEAKY, 0, 0, 0, 0);
//    
//    float data[] = {
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//        1, 1, 1, 1, 1,
//    };
//    
//    network net=make_network(1);
//    net.h=5;
//    net.w=5;
//    net.c=3;
//    net.workspace=calloc(1, l.workspace_size);
//    //printf("\n%zd",l.workspace_size);
//    net.batch=1;
//    net.input=data;
//    
//    memset(l.output, 0, sizeof (float) * l.out_h * l.out_w * l.out_c);
//    
//        int h = l.out_h;
//        int w = l.out_w;
//        int c = l.n;
//
//        
//        image iw = float_to_image(l.size, l.c, l.n, l.weights);
//        image ib = float_to_image(l.size, l.c, l.n, l.biases);
//        printf("weights:\n");
//        print_image(iw);
//        printf("biases:\n");
//        print_image(ib);
//        
//        forward_convolutional_layer(l ,net );
//        
//        image im = float_to_image(w, h, c, l.output);
//        printf("3x3 filter:\n");
//        print_image(im);
////        
////        backward_convolutional_layer(l ,net );
////        
////        im = float_to_image(w, h, c, l.output);
////        printf("3x3 filter:\n");
////        print_image(im);
//        fflush(stderr);
//}
//
//int main(){
//    text_convolutional_output();
//}