from boolean_operators import *
from math_operators import *
from keywords import *

opertors = ["=", "+=", "-=", "*=", "/=", "==", "not", "<", ">"]
keywords_lst = ["while", "shout", "if"]
variables = []
out = []


def handle_commands(lines):

    buffer = []
    i = 0
    k = ''

    while i < len(lines):
        has_keyword = False
        line = lines[i].replace("\n", '')

        if line == '':
            i += 1
            continue
        buffer.append(line)

        for keyword in keywords_lst:
            if keyword in line:
                has_keyword = True
                break

        if has_keyword:
            k = line[:line.index('(')]
            print("keyword:", k)
            if keyword == "while" or keyword == "if":
                while '}' not in line:
                    i += 1
                    line = lines[i]
                    buffer.append(line)
                handle_keyword(buffer, k)

            elif keyword == "shout":
                handle_keyword(buffer, k)

        else:
            handle_buffer(buffer)

        i += 1
        buffer.clear()


def handle_buffer(buffer):
    found = False

    lines = ''
    for command in buffer:
        if command != '':
            lines += command

    if lines == '':  # empty line
        return

    sep = lines.split()

    #  operators
    for opertor in opertors:
        if opertor in sep:
            found = True
            sep.remove(opertor)
            handle_op(sep, opertor)
            break

    if not found:
        raise NameError("Keyword/ operator doesn't exists", buffer)


def handle_op(sep, operator):
    global out

    if operator == '=':
        initialization(sep, variables)
    elif operator == "+=":
        plus(sep, variables)

    elif operator == "-=":
        sub(sep, variables)

    elif operator == "*=":
        mul(sep, variables)

    elif operator == "/=":
        div(sep, variables)

    elif operator == "==":
        out.append(str(equals(sep, variables)))

    elif operator == "not":
        out.append(str(not_op(sep, variables)))

    elif operator == '<':
        out.append(str(smaller(sep, variables)))

    elif operator == '>':
        out.append(str(greater(sep, variables)))

    else:
        print("unknown operator")


def handle_keyword(sep, keyword):
    print(keyword)
    if keyword == "while":
        while_loop(sep, variables, handle_commands)

    elif keyword == "shout":
        out.append(shout(sep, variables))

    elif keyword == "if":
        if_con(sep, variables, handle_commands)

    else:
        raise NameError("unknown keyword")
