#!/bin/bash
# outputs a table of terminal colors

i=0
while [[ $i -lt 25 ]]
do
	j=0
	while [[ $j -lt 10 ]]
	do
		col=$((i*10+j))
		if [[ $col -lt 10 ]]; then
			spaces="  "
		elif [[ $col -lt 100 ]]; then
			spaces=" "
		else
			spaces=""
		fi
		echo -n " $spaces$(tput setaf $col)$col$(tput sgr0) $(tput setab $col) $(tput sgr0)"
		((j++))
	done
	echo ""
	((i++))
done
	
