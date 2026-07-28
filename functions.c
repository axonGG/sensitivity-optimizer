#include "functions.h"

float lowF[]={0.5, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 1};
float highF[]={1.5, 1.5, 1.4, 1.3, 1.2, 1.1, 1.05, 1};

ss generator(float base, char choice, int index){
    float src = base/1.7;
    if (choice == 'H' || choice == 'h') {
        if (index == 6) {
            base *= highF[index];
        } else {
            base += src/2;
        }
    }
    else if (choice == 'L' || choice == 'l') {
        if (index == 6) {
            base *= lowF[index];
        } else {
            base -= src/1.7;
        }
    }
    ss out;
    out.base = base;
    out.low = base*lowF[index];
    out.high = base*highF[index];
    return out;
}