# BitInt library for ARM Assembly

## Summary
After writing a basic implementation of RSA encryption/decryption in Assembly, I wrote this library to allow using arbitrarily sized keys instead of only 32-bit keys.

Consequently, the functions implemented are the ones I used in the RSA program:
+ Addition
+ Multiplication
+ Modulo
+ Logical Shift Left
+ Two's complement conversion
+ Comparing two BigInts
+ Conversion from binary to decimal and vice versa 
+ Parsing a decimal-format input string
+ Printing the number in decimal format

## Notes
The code was written for 32-bit ARMv7
