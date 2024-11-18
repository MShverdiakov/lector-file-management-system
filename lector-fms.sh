#!/bin/bash
# Функция для вывода справки по использованию
show_help() {
    echo "Использование: $(basename "$0") [опции] аргументы"
    echo "Опции:"
    echo "  -g Группа                 Задает номер группы для поиска"
    echo "  -t Тесты                  Вывести студентов с наилучшими результатами по всем годам сдачи тестов"
    echo "  -h                        Справка по ключам"
	echo "  -d Досье                  Интерактивый просмотр досье студента с заданной фамилией"
}

# Функция для поиска студентов с максимальным количеством троек, четверок и пятерок
max_grades_student() {
    local group="$1"
    result=$(grep ",${group}," */tests/* | awk -F, '
        {
            if ($5 == 3) count3[$2]++
            if ($5 == 4) count4[$2]++
            if ($5 == 5) count5[$2]++
        }
        END {
            max_count3 = 0; max_count4 = 0; max_count5 = 0
            student3 = ""; student4 = ""; student5 = ""

            for (student in count3) {
                if (count3[student] > max_count3) {
                    max_count3 = count3[student]
                    student3 = student
                }
            }
            for (student in count4) {
                if (count4[student] > max_count4) {
                    max_count4 = count4[student]
					student4 = student
                }
            }
            for (student in count5) {
                if (count5[student] > max_count5) {
                    max_count5 = count5[student]
					student5 = student
                }
            }

            print "3 -", student3, "- максимальное количество троек:", max_count3
            print "4 -", student4, "- максимальное количество четверок:", max_count4
            print "5 -", student5, "- максимальное количество пятерок:", max_count5
        }'
    )
    echo "$result"
}

# Функция для вывода списка группы, упорядоченного по посещаемости
list_group_by_attendance() {
    local group="$1"
    
    # Поиск всех файлов посещаемости для заданной группы
    attendance_files=$(find . -type f -name "${group}-attendance")

    if [[ -z "$attendance_files" ]]; then
        echo "Файлы посещаемости для группы ${group} не найдены!"
        return
    fi

    declare -A attendance

    # Чтение каждого файла и подсчет посещений
    for file in $attendance_files; do
        while IFS=' ' read -r name presence; do
            # Подсчет количества символов "+" в переменной presence
            num_present=0
            for (( i=0; i<${#presence}; i++ )); do
                [[ "${presence:$i:1}" == "+" ]] && ((num_present++))
            done

            # Суммируем посещения для каждого студента
            attendance["$name"]=$((attendance["$name"] + num_present))
        done < "$file"
    done

    # Сортировка и вывод
    for student in "${!attendance[@]}"; do
        echo "${attendance[$student]} - $student"
    done | sort -rn
}


# Функция для вывода студентов с наилучшими результатами за каждый год
top_students_by_year() {
    declare -A year_best_student  # Ассоциативный массив для хранения лучших студентов
    declare -A year_best_score    # Ассоциативный массив для максимальных баллов по каждому году
    declare -A scores             # Ассоциативный массив для сумм баллов студентов по каждому году

    # Проходим по всем файлам тестов
    for test_file in */tests/TEST-*; do
        while IFS=',' read -r year name group correct_answers grade; do
            # Пропускаем строки, если данные некорректны
            [[ -z "$year" || -z "$name" || -z "$correct_answers" ]] && continue

            # Создаем ключ как строку
            year_student_key="${year}_${name}"
            
            # Суммируем количество правильных ответов для каждого студента в каждом году
            scores["$year_student_key"]=$((scores["$year_student_key"] + correct_answers))

            # Обновляем лучший результат, если текущий результат выше
            if [[ ${scores["$year_student_key"]} -gt ${year_best_score["$year"]:-0} ]]; then
                year_best_score["$year"]=${scores["$year_student_key"]}
                year_best_student["$year"]=$name
            fi
        done < "$test_file"
    done

    # Выводим лучших студентов по каждому году
    echo "Лучшие студенты по количеству правильных ответов за каждый год:"
    for year in $(printf "%s\n" "${!year_best_student[@]}" | sort); do
        echo "Год: $year - ${year_best_student[$year]} (${year_best_score[$year]} правильных ответов)"
    done
}

# Функция для интерактивного просмотра досье с горячими клавишами
interactive_dossier_view() {
    local last_name="$1"
    local dossier_file="./students/general/notes/${last_name:0:1}Names.log"

    if [[ ! -f "$dossier_file" ]]; then
        echo "Файл с досье для фамилии $last_name не найден."
        return
    fi

    # Поиск всех совпадений last_name в файле
    matching_lines=$(grep "$last_name" "$dossier_file")

    # Подсчет количества совпадений
    match_count=$(echo "$matching_lines" | wc -l)

    # Проверка на количество совпадений
    if [[ "$match_count" -gt 1 ]]; then
        echo "Ошибка: фамилия '$last_name' соответствует нескольким полным именам:"
        echo "$matching_lines"
        return
    elif [[ "$match_count" -eq 0 ]]; then
        echo "Ошибка: для фамилии '$last_name' совпадений не найдено."
        return
    fi

    # Если совпадение только одно, извлекаем полное имя и досье
    full_name=$(echo "$matching_lines" | cut -d' ' -f1)
    dossier=$(awk -v name="$last_name" '$0 ~ name {getline; print}' "$dossier_file")

    if [[ -z "$dossier" ]]; then
        echo "Досье для фамилии $last_name не найдено в файле $dossier_file."
        return
    fi

    # Выводим информацию о студенте
    echo "Открыто досье студента $full_name. Используйте горячие клавиши для управления."
    echo "Нажмите 'a' для добавления новой фразы, 'd' для удаления досье, 'q' для выхода."
    echo
    echo "$dossier"

    while :; do
        read -n 1 -p "Нажмите 'a' (добавить), 'd' (удалить), 'v' (просмотр), 'q' (выход): " choice
        echo
        case $choice in
            a)
                # Запрос новой фразы и добавление её в досье
                read -rp "Введите новую фразу для добавления: " new_phrase
                escaped_dossier=$(printf '%s\n' "$dossier" | sed 's/[]\/$*.^|[]/\\&/g')
                # Добавляем new_phrase после dossier в файле
                sed -i "s/${escaped_dossier}/${escaped_dossier} ${new_phrase}/" "$dossier_file"
                echo "Фраза добавлена в досье студента $full_name."
                ;;
            d)
                echo "Вы действительно хотите удалить досье студента $full_name? (y/n)"
                read -r confirm
                if [[ "$confirm" == "y" ]]; then
                    # Удаляем блок досье студента до первого разделителя
                    sed -i "/^${last_name}/,/^=====================================/{d}" "$dossier_file"
                    echo "Досье студента $full_name удалено."
                    break
                else
                    echo "Удаление отменено."
                fi
                ;;
			v)
                # Вывод досье на экран
				dossier=$(awk -v name="$last_name" '$0 ~ name {getline; print}' "$dossier_file")
                echo "Текущее досье студента $full_name:"
                echo "$dossier"
                ;;
            q)
                echo "Выход из интерактивного режима досье."
                break
                ;;
            *)
                echo "Неверная клавиша. Попробуйте снова."
                ;;
        esac
    done
}





# Переменные для группы и флага вывода результатов по годам
GROUP=""
SHOW_TOP_BY_YEAR=0
LAST_NAME=""
ACTION=""

# Обработка ключей
while getopts ":g:d:ht" opt; do
    case $opt in
        g) GROUP=$(echo "$OPTARG" | sed 's/А/A/g;') ;;
        t) SHOW_TOP_BY_YEAR=1 ;;
        h) show_help; exit 0 ;;
		d) LAST_NAME="$OPTARG"; ACTION="interactive" ;;
        \?) echo "Неверный параметр: -$OPTARG" >&2; exit 1 ;;
        :) echo "Опция -$OPTARG требует аргумента." >&2; exit 1 ;;
    esac
done

# Выполнение действий в зависимости от переданных параметров
if [[ $SHOW_TOP_BY_YEAR -eq 1 ]]; then
    # Если указан ключ -t, выводим лучших студентов по годам сдачи тестов
    top_students_by_year
elif [[ -n "$GROUP" ]]; then
	# Проверяем, существует ли информация по указанной группе
    group_files=$(find . -type f -name "${GROUP}-*")
    if [[ -z "$group_files" ]]; then
        echo "Ошибка: Для группы '$GROUP' данные не найдены. Проверьте правильность ввода."
        exit 1
    fi

    # Если указана группа, предлагаем выбор действия
    echo "Выберите действие для группы $GROUP:"
    echo "1 - Вывести имена студентов с максимальным количеством троек, четверок и пятерок"
    echo "2 - Вывести список группы, упорядоченный по посещаемости"
    read -rp "Введите номер действия (1 или 2): " choice

    case $choice in
        1)
            echo "Поиск студентов с максимальным количеством оценок 3, 4 и 5 в группе $GROUP"
            max_grades_student "$GROUP"
            ;;
        2)
            echo "Вывод списка группы $GROUP, упорядоченного по посещаемости"
            list_group_by_attendance "$GROUP"
            ;;
        *)
            echo "Неверный выбор. Пожалуйста, выберите 1 или 2."
            ;;
    esac
elif [[ -n "$LAST_NAME" ]]; then
    case $ACTION in
        "interactive") interactive_dossier_view "$LAST_NAME" ;;
    esac
else
    echo "Группа не указана или не выбран параметр -t. Используйте ключ -g для выбора группы или -t для вывода лучших студентов по годам."
    show_help
fi
