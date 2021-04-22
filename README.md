<p align="center">
  <img width="460" height="400" src="https://github.com/HomiGrotas/Dorina/blob/main/images/dorinaImage.png?raw=true">
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
intro = "Welcome to Dorina!"
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


## While statement
Uses same operators as the if statement
```
counter = 0
while counter < 10
shout "counting"
shout counter
counter += 1
endwhile
```

## Limits
* Int on initialization - 2 digits (max 99) 
* Int after math operations - max 65535 (word size)
* String - max length of 20 digits
* Notice, there should be a blank line only at the end of the code file
* Notice, there shouldn't be spaces at end of a line.
