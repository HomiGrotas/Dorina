def plus(sep, variables: list):
    """
    add value to var
    """
    var = False

    for s in sep:
        if not s[0].isdigit():
            var = True
            break

    if var:
        for ind in range(0, len(variables), 2):
            v = variables[ind]
            if v == sep[0]:
                if sep[1].isdigit():  # x += 5
                    variables[ind+1] += int(sep[1])
                else:  # x += y
                    variables[ind+1] += variables[variables.index(sep[1])+1]


def sub(sep, variables):
    """
    subtract a var
    """
    var = False

    for s in sep:
        if not s[0].isdigit():
            var = True
            break

    if var:
        for ind in range(0, len(variables), 2):
            v = variables[ind]
            if v == sep[0]:
                if sep[1].isdigit():  # x -= 5
                    variables[ind+1] -= int(sep[1])
                else:  # x-= y
                    variables[ind+1] -= variables[variables.index(sep[1])+1]
            ind += 2


def mul(sep, variables):
    """
    multiply a var
    """
    var = False

    for s in sep:
        if not s[0].isdigit():
            var = True
            break

    if var:
        for ind in range(0, len(variables), 2):
            v = variables[ind]
            if v == sep[0]:
                if sep[1].isdigit():  # x *= 5
                    variables[ind+1] *= int(sep[1])
                else:  # x *= y
                    variables[ind+1] *= variables[variables.index(sep[1])+1]
            ind += 2


def div(sep, variables):
    """
    divide var
    """
    var = False

    for s in sep:
        if not s[0].isdigit():
            var = True
            break

    if var:
        for ind in range(0, len(variables), 2):
            v = variables[ind]
            if v == sep[0]:
                if sep[1].isdigit():  # x /= 2
                    variables[ind + 1] /= int(sep[1])
                else:  # x /= y
                    variables[ind + 1] /= variables[variables.index(sep[1]) + 1]
            ind += 2


def initialization(sep: list, variables: list):
    """
    define a var
    """
    if sep[0] in variables:
        if sep[1] != "False" and sep[1] != "True":  # already exists
            variables[variables.index(sep[0])+1] = int(sep[1])
        else:
            variables.append(sep[0])  # var name
            variables[variables.index(sep[0])+1] = sep[1] == 'True'  # var value

    else:  # x = 5
        if sep[1].isdigit():
            variables.append(sep[0])       # var name
            variables.append(int(sep[1]))  # var value
        elif sep[1][0] == '"':  # x = "hello"
            variables.append(sep[0])  # var name
            variables.append(str(sep[1][1:-1]))  # var value
        else:  # x = y
            if sep[1] != "False" and sep[1] != "True":
                variables.append(sep[0])       # var name
                variables.append(variables[variables.index(sep[1])+1])  # var value
            else:  # x = False
                variables.append(sep[0])       # var name
                variables.append(sep[1] == 'True')  # var value
