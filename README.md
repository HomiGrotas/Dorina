<p align="center">
  <img width="460" height="300" src="https://github.com/HomiGrotas/Dorina/blob/main/images/dorinaImage.png?raw=true">
</p>

# Dorina programming language
A simple programming language with an assembly interpreter and a python interpreter.
This is the final project of my assembly learning.






## Stages:
- [x] design the language
- [x] build a python interpreter
- [ ] build an assembly interpreter based on the python version











## Goal:
 The goal of this project is to build an assembly interpreter for the programming language I made (Dorina).
 This project is for my Magen grade.
 
 
 
 
 
 
 
 
 
 
 # Documentation

 ## Variables Declaration
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
x %= 2
```

## If statement
* <
* &gt;
* ==
* !=
* <=
* &gt;=
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

```
my_age = 16
if my_age >= 18
shout "You can enter the club! Enjoy!"
endif
```


## Limits
* Int on initialization - 2 digits (max 99) 
* Int after math operations - max 65535 (word size)
* String - max length of 2 digits

coming soon: while loop
