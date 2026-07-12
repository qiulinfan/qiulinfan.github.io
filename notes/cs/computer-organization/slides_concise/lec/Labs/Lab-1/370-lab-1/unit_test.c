// EECS 370 Lab 1
// YOU MAY MODIFY THIS FILE BUT DON'T SUBMIT
#define ARR_SIZE 5
#include <stdio.h>
#include <stdlib.h>
#include "lab1.h"

/*
int main() {
    if (extract(0x2020) != 0b0010) {
        printf("Extract Test failed :(\n");
        exit(1);
    }
    printf("Passed! :)\n");
}
*/

typedef struct My_Struct {
  int i;
  char c;
} My_Struct;
 
int main() {
  My_Struct my_arr[ARR_SIZE];
  for(int i=0; i<ARR_SIZE; i++) {
    my_arr[i].i = (i << 4) * 3 - (2 << i);
     my_arr[i].c = my_arr[i].i;
  }

  my_arr[2].c = 'a';
  return 0;
}
