s/[a-z]\+/<span class = "r">\0<\/span>/g
s/[A-Z]\+/<span class = "g">\0<\/span>/g
s/"[A-Z]\+"/<span class = "f">\0<\/span>/g
1s/^/<style>.f{color:#c38e22}.r{color:#1b6e98}.g{color:#00a4b3}<\/style>\n/
