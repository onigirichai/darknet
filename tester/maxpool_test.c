/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
#include <stdio.h>
#include"maxpool_test.h"
#include"../src/maxpool_layer.h"

void test_maxpool_output(){
    maxpool_layer l=make_maxpool_layer(1,5,5,3,2,2,0);
    l.n=1;
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
    net.batch=1;
    net.input=data;
    
    int h = l.out_h;
    int w = l.out_w;
    int c = l.n;
    
    forward_maxpool_layer(l,net);
    image im = float_to_image(w, h, net.c, l.output);
    printf("3x3 filter:\n");
    print_image(im);
}

int main(){
    test_maxpool_output();
}