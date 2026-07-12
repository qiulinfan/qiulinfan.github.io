// EECS 370 SP 23 - Lab 2
// MODIFY AND SUBMIT THIS FILE
#include "numHighBits.h"

// Takes in an integer as an argument, and returns the number of bits set high in its binary representation
int numHighBits(int input){
    int count = 0;
    while (input != 0) {
        if(input & 0x80000000){count++;}
        input = (input << 1) & 0xFFFFFFFF;
    }
    return count;
}
