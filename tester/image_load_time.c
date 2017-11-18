/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

/* 
 * File:   image_load_time.c
 * Author: xuyufan
 *
 * Created on 2017年11月16日, 下午12:09
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <sys/time.h>

#include "../include/darknet.h"
#include "../src/option_list.h"
#include "../src/data.h"
#include "../src/list.h"
#include "../src/image.h"
#include "../src/utils.h"


void image_load_time(){
    char datacfg[]="../cfg/imagenet_img.data";
    list *options = read_data_cfg(datacfg);
    
    char *train_list = option_find_str(options, "train", "data/train.list");
    char *label_list = option_find_str(options, "labels", "data/labels.list");
    
    list *plist = get_paths(train_list);
    char **paths = (char **)list_to_array(plist);
    char **labels = get_labels(label_list);

    printf("%d\n",plist->size);
    int N=plist->size;
    double time;
    
    float sum_time=0;
    tree *hierarchy;
    load_args args={0};
    args.w=224;
    args.h=224;
    args.min=224;
    args.max=340;
    args.threads=2;
    //args.hierarchy=hierarchy;
    args.aspect=1;
    args.exposure=1;
    args.saturation=1;
    args.hue=0;
    args.classes=1000;
    args.size=224;
    
    args.paths = paths;
    args.labels = labels;
    args.m=N;
    args.n=128;
    args.type=CLASSIFICATION_DATA;
   
    
    data train;
    data buffer;
    pthread_t load_thread;
    args.d = &buffer;
    
    for(int i=0;i<10;i++){
        time = what_time_is_it_now();
        
        load_thread = load_data(args);
        pthread_join(load_thread, 0);
        
        
        
        printf("Loaded: %lf seconds\n",what_time_is_it_now()-time);
        sum_time+=what_time_is_it_now()-time;
        printf("%d\n\n",i);
    }
    printf("average loading time is : %f\n",sum_time/10);
}
void time_crop_image(){
    char **paths=calloc(1,sizeof(char *));
    double time;
    double sum_time=0;
    image im={0};
    for(int i=0;i<64;i++){
    paths[0]="/home/xuyufan/imagenet_all/ILSVRC2012_img_train/n01440764_4613.JPEG";
    im = load_image_color(paths[0], 0, 0);
    time= what_time_is_it_now();
    random_augment_image(im, 0, 1, 0, 340, 224, 224);
    printf("Loaded: %lf seconds\n",what_time_is_it_now()-time);
    sum_time+=what_time_is_it_now()-time;
    }
    printf("average loading time is : %f\n",sum_time/64); 
    if(paths==NULL)
    free(paths);
    paths=NULL;
}
/*
 * 
 */
int main(int argc, char** argv) {
    image_load_time();
    //time_crop_image();
}

