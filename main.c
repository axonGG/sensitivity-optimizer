#include <stdio.h>
#include "functions.c"

int main() {
    float base;
    printf("Enter base sensitivity: ");
    scanf("%f", &base);
    printf("\n");
    for (int i = 0; i < 7; i++) {
        char choice='\0';
        ss sent= generator(base,choice,i);
        printf("[H]High: %g     Base: %g        [L]Low: %g\n\n", sent.high, sent.base, sent.low);
        printf("Select(H/L): ");
        scanf(" %c", &choice);
        getchar();
        if (choice == 'H' || choice == 'h' || choice == 'L' || choice == 'l') {
            ss updated = generator(base,choice,i);
            base = updated.base;
        }
        else {
            printf("Invalid Choice! Try again.......\n\n");
            i--;
        }
    }
    printf("\nFinal optimized base sensitivity: %g\n", base);
    printf("\nPress Enter to exit...");
    getchar();
    return 0;
}