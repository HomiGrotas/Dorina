#!/usr/bin/env python
# -*- coding: utf-8 -*-
from handle import *


with open("code.dorina", encoding='UTF-8') as r:
    lines = r.readlines()
    handle_commands(lines)


print("\n\n", variables, "\n_______________________________________")
print("out:")
print('\n'.join(out))
