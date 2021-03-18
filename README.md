# Dorina programming language
Simple programming language with assembly interpeter and python interpeter.
This is the final project of my assembly learning.






## Stages:
- [x] design the language
- [x] build a python interpeter
- [ ] build an assembly interpeter based on the python version











## Goal:
 The goal of this project is to build an assembly interpreter for the programming language I made (Dorina).
 This project is for my Magen grade.
 
 
 
 
 
 
 
 
 
 
 # Documentation

 ## Variables Decleration
 ### Integers
```
x = 5
myAge = 16
```


### Strings
```
hello = "hi"
me = "I"
```



## Display variables
```
shout x
shout myAge
```






## Display text
```
shout "Hello World!"
```







## Math Operators
```
x += 1
x -= 1
x *= 1
x /= 1
x ^= 1
```

## If statement
```
x = 0
if x < 10
shout "x is smaller than 10"
endif
```

```
x = 5
if x != 5
shout x
endif
```

## Limits
* Int on initialization - 2 digits (max 99) 
* Int after math operations - max 65535 (word size)
* String - max length of 2 digits

coming soon: while loop
