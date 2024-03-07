while :
do
    echo -ne "\033[Kwaiting for internet connection."\\r
    sleep 0.1
    echo -ne "\033[Kwaiting for internet connection.."\\r
    sleep 0.1
    echo -ne "\033[Kwaiting for internet connection..."\\r
    sleep 0.1
    counter=$((counter+1))
    if [ $counter -eq 60 ]; then
        echo -e "\033[Kwaiting for internet connection..."
        echo "no internet connection"
        exit 1
    fi
done
