#!/bin/bash
# outputs a table of terminal colors
#
# if "dump" is given as argument,
# outputs a list of <num> <FG code> <BG code> separated by newlines
# (meant to be cat -v'd)

i=0
while [[ $i -lt 26 ]]
do
	j=0
	while [[ $j -lt 10 ]]
	do
		col=$((i*10+j))
		if [[ $1 == "dump" ]];then
			echo "$col $(tput setaf $col) $(tput setab $col)"
		else
			if [[ $col -lt 10 ]]; then
				spaces="  "
			elif [[ $col -lt 100 ]]; then
				spaces=" "
			else
				spaces=""
			fi
			echo -n " $spaces$(tput setaf $col)$col$(tput sgr0) $(tput setab $col) $(tput sgr0)"
		fi
		((j++))
	done
	echo ""
	((i++))
done


