/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

/* 
 * File:   charify_image.c
 * Author: xuyufan
 *
 * Created on 2017年10月24日, 下午2:51
 */

#include <stdio.h>
#include <stdlib.h>
#include "../src/image.h"
#include "../include/darknet.h"
/*
 * 
 */
typedef struct image1{
    int w,h,c;
    char *data;
}image1;
image1 func(){
    image1 img;//={0,0,0,NULL};
    return  img;
}
image load_image_stb(char *filename, int channels);

int main(int argc, char** argv) {
    char **paths=(char**)calloc(2,sizeof(char*));
    image charify;
    image1 img;//={0,0,0,NULL};
    img=func();
    int flag=1;
    paths[0]="/home/xuyufan/n01739381_130.JPEG";
//    paths[1]="/home/xuyufan/imagenet_all/ILSVRC2012_img_train/n01440764_1995.JPEG";
    paths[1]="/home/xuyufan/imagenet_all/ILSVRC2012_img_train/n07583066_647.JPEG";
//    paths[0]="/home/xuyufan/imagenet_all/ILSVRC2012_img_train/n13037406_510.JPEG";
    charify=load_image_stb(paths[0],3);
    if(charify.data==NULL){
        flag=0;
    }
    printf("%d\n",flag);
    return (EXIT_SUCCESS);
}

