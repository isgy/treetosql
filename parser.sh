#!/bin/bash

last_parent=()
parents=()
prev_indent=()
declare -i current_id=0
parent_id=()
runsql() {
    if [ $# != 2 ]; then
            echo "runsql has wrong number of arguments, see -h for help"
            exit 1
    fi
    last_parent+=('')
    setnext=-1
    while IFS= read -r line
    do
       par=${last_parent[-1]}
      # echo "parent: " $par
      if [ ${#last_parent[@]} == 1 ]; then                      # inserts first item (assuming it's C:\ here) into the database
           sudo -iu postgres <<EOSU
             psql -d $2 -c "INSERT INTO dirs VALUES (1, NULL, TRUE, 'C:\');"
EOSU
            last_parent+=('C:\')
            parent_id+=('')
            current_id+=1
            prev_indent+=('0')
            parents+=( ["$current_id"]=${parent_id[-1]} )
            echo "CURRENT ID : $current_id     ======  PARENTID : ${parents["$current_id"]}"
       fi

       if [ -z "$(echo "$line" | grep '<b>')" ]; then       #checks if item is a folder (r) or file (b)
           echo 'red(folder)'
           isfolder=true
       else
           echo 'blue(file)'
           isfolder=false
       fi


       current_indent=$(echo "$line" | awk -F'[^ ^\t]' '{print length($1)}')   #gets the indent of the current line
       p_indent=${prev_indent[-1]}
       current_item=$(echo "$line" | grep -Po '((\w+( \w*)*)|(\w+\.\w{3,4})) (?=<)')

       if [[ $current_indent -eq $p_indent ]] && [[ $current_indent -ne 0 ]]; then  #item is on the same level as the previous item
          # echo "CURRENTINDENT $current_indent     PREVINDENT: $p_indent"
          # echo "curr: $current_id     prev: ${parent_id[-1]}"
          # echo "SAMEINDENT ------------"
           current_id+=1                                          #do not add to parent_id stack because the indent is the same
           parents+=( ["$current_id"]=${parent_id[-1]} )          #as the previous line
           parID=${parents["$current_id"]}                                 #add the parent_id to the parents array with the current_id as key
           echo "CURRENT ID : $current_id     ======  PARENTID : $parID"   #so that the current id maps to the parent id

           sudo -iu postgres <<EOSU
             psql -d $2 -c "INSERT INTO dirs VALUES ($current_id, $parID, $isfolder, '$current_item');"
EOSU


       elif [[ $current_indent -lt $p_indent ]] && [[ $current_indent -ne 0 ]]; then  #item is on a higher level

          while [[ $current_indent -lt $p_indent ]] && [[ $current_indent -ne 0 ]]
          do
                                                                              #if item is still on a higher level
             unset 'prev_indent[((${#prev_indent[@]}-1))]'                    #remove parent_id from the stack and remove the indent of
             unset 'parent_id[((${#parent_id[@]}-1))]'                        #that parent_id
             echo "${#prev_indent[@]}"
             echo "${#parent_id[@]}"
                                                                              #loops through previous indents until the current
                                                                              #indent is greater than or equal to the previous indent
             if [[ current_indent -gt ${prev_indent[-1]} ]] || [[ current_indent -eq ${prev_indent[-1]} ]]; then
                break
             fi
          done
          echo "---$current_id -- ${parent_id[-1]}"
          current_id+=1
          parents+=( ["$current_id"]=${parent_id[-1]} )
          parID=${parents["$current_id"]}

          echo "CURRENT ID : $current_id     ======  PARENTID : ${parents["$current_id"]}"
          sudo -iu postgres <<EOSU
             psql -d $2 -c "INSERT INTO dirs VALUES ($current_id, $parID, $isfolder, '$current_item');"
EOSU

          prev_indent[-1]=$current_indent


       else
                                                                             # the block will run if [ $current_indent > $p_indent ]
           if [[ $current_indent -ne 0 ]]; then
        #   echo "CURRENTINDENT $current_indent     PREVINDENT: $p_indent"
        #   echo
        #   echo "DEEPERINDENT----------------------------"
           parent_id+=("$current_id")                                      #add the current_id to the parent_id stack
           current_id+=1
           parents+=( ["$current_id"]=${parent_id[-1]} )
           parID=${parents["$current_id"]}

           echo "CURRENT ID : $current_id     ======  PARENTID : ${parents["$current_id"]}"
           sudo -iu postgres <<EOSU
             psql -d $2 -c "INSERT INTO dirs VALUES ($current_id, $parID, $isfolder, '$current_item');"
EOSU

           prev_indent+=("$current_indent")                     #adds current indent to prev_indent so it can be compared at the next line
           fi
       fi

              echo "$line" | awk '{print $1}'
       echo
       echo

    done < $1
}

outfile(){
    if [ $# != 3 ]; then
            echo "wrong number of arguments, see -h for help"
            exit 1
    fi

    while IFS= read -r line                               #TODO
    do
       echo "$line"
    done < $1
}


r=-1
while getopts ":hsf" opt; do                                 #option to runs code to insert sql or write to a file
  case ${opt} in
    s ) r=1
      ;;
    f ) r=0
      ;;
    h ) echo "Usage: $0 [option...] {file_to_read} {database_to_insert_into} [output sql file]"
         echo
         echo "   -h, --help                 show this help message "
         echo "   -f, --output to sql file   sends output to <today's date>_dirs.sql"
         echo
         exit 1
      ;;
  esac
done

echo "Parsing txt file"

if [ r != 0 ]
then
    runsql $2 $3
else
    outfile $2 $3 $4
fi


