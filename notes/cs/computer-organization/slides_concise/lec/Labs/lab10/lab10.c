#include <stdlib.h>
#include <stdio.h>

typedef struct {
    char a;
    float b;
    short c;
    unsigned int d;
    char e;
    int f;
} example;

void init_struct(example *ex);
void access_struct(example *ex);


const int ITER_COUNT = 300000000;

int main(int argc, char** argv) {
    int arr_size = atoi(argv[1]);
    example *e = malloc(arr_size*sizeof(example));
    for(int i=0; i<arr_size; i++) {
        init_struct(&e[i]);
    }
    for(int i=0; i<ITER_COUNT; i++) {
        access_struct(&e[i % arr_size]);
    }
    free(e);
}


void init_struct(example *ex) {
    ex->a = 1;
    ex->b = 2;
    ex->c = 3;
    ex->d = 4;
    ex->e = 5;
    ex->f = 6;
}

void access_struct(example *ex) {
    int count = 0;
    count += (int) ex->a;
    count += (int) ex->b;
    count += (int) ex->c;
    count += (int) ex->d;
    count += (int) ex->e;
    count += (int) ex->f;
}

