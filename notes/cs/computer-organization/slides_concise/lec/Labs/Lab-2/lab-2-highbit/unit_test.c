// EECS 370 SP 23 - Lab 2
// YOU MAY MODIFY THIS FILE BUT DON'T SUBMIT

#include <stdio.h>
#include <stdlib.h>
#include "numHighBits.h"

int instructorTest() {
    return numHighBits(24) == 2;
}
int main() {
    if (numHighBits(24) != 2) {
        printf("Test failed :(\n");
        exit(1);
    }
    printf("Passed! :)\n");
}