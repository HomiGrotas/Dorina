from boolean_operators import *
from math_operators import *


def _eval_commands(commands, handle_commands):
    handle_commands(commands)


def while_loop(sep, variables, handle_commands):
    loop_content = sep[2:-1]
    loop_content = [line.strip() for line in loop_content]
    loop_condition = (sep[0][sep[0].index('(')+1:-1]).split()
    loop_condition_op = loop_condition.pop(1)

    print("loop_content:", loop_content)
    print("loop_condition:", loop_condition)
    print("loop_op:", loop_condition_op)

    if loop_condition_op == '<':
        while smaller(loop_condition, variables):
            _eval_commands(loop_content, handle_commands)

    elif loop_condition_op == '==':
        while equals(loop_condition, variables):
            _eval_commands(loop_content, handle_commands)

    elif loop_condition_op == '>':
        while greater(loop_condition, variables):
            _eval_commands(loop_content, handle_commands)


def shout(sep, variables):
    content = sep[0][6:-1]
    if content[0] != '"':
        content = str(variables[variables.index(content)+1])
    return content


def if_con(sep, variables, handle_commands):
    if_content = sep[2:-1]
    if_content = [line.strip() for line in if_content]
    if_condition = (sep[0][sep[0].index('(') + 1:-1]).split()
    if_condition_op = if_condition.pop(1)

    print("if_content:", if_content)
    print("if_condition:", if_condition)
    print("if_op:", if_condition_op)

    if if_condition_op == '<':
        while smaller(if_condition, variables):
            _eval_commands(if_content, handle_commands)

    elif if_condition_op == '==':
        while equals(if_condition, variables):
            _eval_commands(if_content, handle_commands)

    elif if_condition_op == '>':
        if greater(if_condition, variables):
            _eval_commands(if_content, handle_commands)
