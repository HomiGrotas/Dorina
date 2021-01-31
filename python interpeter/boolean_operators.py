def equals(sep, variables: list):
    """
    var1 == var2, var1 == 10
    """
    if sep[1][0].isdigit():
        return variables[variables.index(sep[0])+1] == int(sep[1])
    return variables[variables.index(sep[0])+1] == variables[variables.index(sep[1])+1]


def greater(sep, variables: list):
    """
    var1 > var2
    """
    if sep[1][0].isdigit():
        return variables[variables.index(sep[0])+1] > int(sep[1])
    return variables[variables.index(sep[0])+1] > variables[variables.index(sep[1])+1]


def smaller(sep, variables: list):
    """
    var1 < var2
    """
    if sep[1][0].isdigit():
        return variables[variables.index(sep[0])+1] < int(sep[1])
    return variables[variables.index(sep[0])+1] < variables[variables.index(sep[1])+1]


def not_op(sep, variables: list):
    """
    !var1
    """
    return not variables[variables.index(sep[0])+1]
