#ifndef functions_h
#define functions_h

typedef struct sens {
    float high;
    float low;
    float base;
} ss;

ss generator(float base, char choice, int index);

void tag();

void title();
#endif
