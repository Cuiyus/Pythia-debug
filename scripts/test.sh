for file in `ls ../src/bubbles`
do
  echo "${file}"
  # echo `basename "${file}"`
  echo "../src/bubbles/${file}"
done
