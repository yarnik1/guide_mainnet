#!/bin/bash

# URL для запиту
URL="http://127.0.0.1:9944"
JSON_DATA='{"jsonrpc":"2.0","method":"bioauth_status","params":[],"id":1}'

# URL для відправки повідомлень в Telegram
TELEGRAM_BOT_TOKEN=""
CHAT_ID=""
TELEGRAM_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$CHAT_ID&text="

# Інтервал між перевірками (в секундах)
INTERVAL=600

# Функція для відправки повідомлення в Telegram
send_telegram_message() {
    local message=$1
    curl -sS "${TELEGRAM_URL}${message}" > /dev/null
}

# Головний цикл моніторингу
while true; do
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "$JSON_DATA" $URL)
    
    # Перевірка, чи є результат у відповіді
    if ! echo $response | jq -e '.result' > /dev/null; then
        echo "⛔ Нода не відповідає"
        send_telegram_message "⛔ Нода не відповідає"
    else
        status=$(echo $response | jq -r '.result | keys[0]')
        expires_at=$(echo $response | jq -r '.result.Active.expires_at // empty')

        # Поточний час в мілісекундах
        current_time=$(($(date +%s%N)/1000000))

        # Перевірка умов
        if [ "$status" != "Active" ]; then
            echo "⛔ Bioauth не активне"
            send_telegram_message "⛔ Bioauth не активне"
        elif [ -n "$expires_at" ]; then
            time_remaining=$((expires_at - current_time))

            if [ "$time_remaining" -le 0 ]; then
                echo "⛔ Bioauth закінчився"
                send_telegram_message "⛔ Bioauth закінчився"
            elif [ "$time_remaining" -le 3600000 ]; then
                echo "⚠️ Bioauth дійсне меньш ніж годину"
                send_telegram_message "⚠️ Bioauth дійсне меньш ніж годину"
            else
                echo "✅ Bioauth status is Active and valid."
            fi
        else
            echo "✅ Bioauth status is Active with no expiration."
        fi
    fi

    if tail -n 3 "/root/.humanode/workspaces/default/tunnel/logs.txt" | grep -q "ERROR"; then
        echo "⛔ Знайдена помилка в RPC logs"
        send_telegram_message "⛔ Знайдена помилка в RPC logs"
    fi

    # Відлік до наступного циклу
    for ((i=INTERVAL; i>0; i--)); do
        printf "\rНаступна перевірка через: %02d:%02d" $((i/60)) $((i%60))
        sleep 1
    done
    echo -e "\r\n"
done
