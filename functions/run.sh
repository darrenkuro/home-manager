function run() {
	if [ $# -eq 0 ]; then
		cc -Wall -Wextra -Werror -x c <(grep -v "////" *.c)
		./a.out
		ret=$?
		/bin/rm a.out
		return $ret
	fi
	if [ $# -eq 1 ]; then
		cc -Wall -Wextra -Werror -x c <(grep -v "////" $1)
		./a.out
		ret=$?
		/bin/rm a.out
		return $ret
	fi
	if [ $# -gt 1 ]; then
		cc -Wall -Wextra -Werror -x c <(grep -v "////" $1)
		# combining all arguments from 2nd one
		./a.out ${*:2}
		ret=$? #save the return code to return later
		/bin/rm a.out
		return $ret
	fi
}
