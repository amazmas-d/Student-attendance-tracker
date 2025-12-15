#!/usr/bin/env bash
# Simple Student Attendance Tracker (Git Bash compatible)
# All options 1..10 implemented (easy version)

attendance_file="attendance.txt"
students_file="students.txt"
summary_file="attendance_summary.txt"
threshold=40   # defaulter threshold %

# Create default students if file doesn't exist
if [ ! -f "$students_file" ]; then
    printf "S101,Azman\nS102,Nusrat\nS103,Rahim\nS104,Sadia\nS105,Arif\n" > "$students_file"
fi

# Load students into an array
load_students() {
    students=()
    while IFS= read -r line || [ -n "$line" ]; do
        students+=("$line")
    done < "$students_file"
}

show_menu() {
    echo "------------------------------------"
    echo "       STUDENT ATTENDANCE TRACKER   "
    echo "1. Mark Attendance"
    echo "2. View Section Info"
    echo "3. View Full Attendance Log"
    echo "4. Search Student (Full Report)"
    echo "5. Attendance Summary"
    echo "6. Attendance Percentage (Class List)"
    echo "7. Defaulter List (< $threshold%)"
    echo "8. Alert System (3 consecutive absences)"
    echo "9. Add / Remove Student"
    echo "10. Exit"
    echo "------------------------------------"
}

# Utility: ensure attendance file exists
ensure_attendance_file() {
    if [ ! -f "$attendance_file" ]; then
        touch "$attendance_file"
    fi
}

# Start main loop
while true; do
    load_students
    show_menu
    read -p "Enter your choice: " choice

    case $choice in
        1)
            # Mark attendance for each student on given date
            read -p "Enter Date (YYYY-MM-DD): " date
            ensure_attendance_file
            echo "Mark attendance: P for present, A for absent"
            for student in "${students[@]}"; do
                IFS=',' read -r sid sname <<< "$student"
                while true; do
                    read -p "Status for $sname ($sid) (P/A): " status
                    status=$(echo "$status" | tr '[:lower:]' '[:upper:]')
                    if [[ "$status" == "P" || "$status" == "A" ]]; then
                        echo "$date,$sid,$sname,$status" >> "$attendance_file"
                        break
                    else
                        echo "Invalid input! Please enter P or A."
                    fi
                done
            done
            echo "✅ Attendance saved."
            ;;

        2)
            # View students list
            echo "---- Section Students List ----"
            echo "ID    | Name"
            echo "------+----------------"
            awk -F, '{printf "%-5s | %s\n", $1, $2}' "$students_file"
            total_students=$(wc -l < "$students_file" | tr -d ' ')
            echo "----------------------------"
            echo "Total Students: $total_students"
            ;;

        3)
            # Full attendance log
            echo "---- Full Attendance Log ----"
            if [ ! -f "$attendance_file" ] || [ ! -s "$attendance_file" ]; then
                echo "No attendance records found."
            else
                cat "$attendance_file"
            fi
            ;;

        4)
            # Search student full report
            echo "Search by: 1) ID  2) Name"
            read -p "Choose 1 or 2: " search_choice

            if [[ "$search_choice" == "1" ]]; then
                read -p "Enter Student ID: " sid_search
                student_info=$(grep -i "^${sid_search}," "$students_file" | head -n1)
            elif [[ "$search_choice" == "2" ]]; then
                read -p "Enter Student Name (exact): " name_search
                # Case-insensitive exact name match
                student_info=$(awk -F, -v n="$name_search" 'tolower($2)==tolower(n){print; exit}' "$students_file")
            else
                echo "Invalid choice!"
                continue
            fi

            if [ -z "$student_info" ]; then
                echo "Student not found!"
                continue
            fi

            target_id=$(echo "$student_info" | cut -d, -f1)
            target_name=$(echo "$student_info" | cut -d, -f2)

            echo "===================================="
            echo " A-to-Z Report for: $target_name ($target_id)"
            echo "===================================="

            # If no attendance file or no record for student, show 0 summary
            if [ ! -f "$attendance_file" ] || ! grep -q "^" "$attendance_file"; then
                echo "Summary:     0 Present / 0 Total Days"
                echo "Percentage:  0.00%"
                echo
                echo "No attendance records found yet."
                continue
            fi

            # Print each record for student, then totals
            awk -F, -v id="$target_id" '
            $2==id { print $1 " | " $4; total++; if($4=="P") present++ }
            END {
                if (total==0) {
                    printf "\nSummary:     0 Present / 0 Total Days\n";
                    printf "Percentage:  0.00%%\n\n";
                    print "No attendance records found yet."
                } else {
                    perc = (present/total)*100;
                    printf "\nSummary:     %d Present / %d Total Days\n", present, total;
                    printf "Percentage:  %.2f%%\n", perc;
                }
            }' "$attendance_file"
            ;;

        5)
            # Attendance summary (table with separators)
            echo "------------- Attendance Summary -------------"
            echo "ID    | Name      | P | A | %"
            echo "--------------------------------------------"
            ensure_attendance_file
            while IFS=',' read -r sid sname || [ -n "$sid" ]; do
                p=$(grep -E "^.*,${sid},.*,[P]$" "$attendance_file" 2>/dev/null | wc -l | tr -d ' ')
                # alternate grep: count lines that have ,SID, pattern (date,sid,name,status)
                p=$(grep -E ",${sid}," "$attendance_file" 2>/dev/null | grep -c ",P" 2>/dev/null || true)
                a=$(grep -E ",${sid}," "$attendance_file" 2>/dev/null | grep -c ",A" 2>/dev/null || true)
                p=${p:-0}
                a=${a:-0}
                total=$((p + a))
                if [ "$total" -eq 0 ]; then
                    perc="0.00"
                else
                    perc=$(awk "BEGIN {printf \"%.2f\", ($p/$total)*100}")
                fi
                printf "%-5s | %-9s | %2d | %2d | %6s%%\n" "$sid" "$sname" "$p" "$a" "$perc"
            done < "$students_file"
            ;;

        6)
            # Attendance Percentage (class list with two decimals)
            echo "------- Attendance Percentage (Class) -------"
            ensure_attendance_file
            while IFS=',' read -r sid sname || [ -n "$sid" ]; do
                p=$(grep -E ",${sid}," "$attendance_file" 2>/dev/null | grep -c ",P" 2>/dev/null || true)
                a=$(grep -E ",${sid}," "$attendance_file" 2>/dev/null | grep -c ",A" 2>/dev/null || true)
                p=${p:-0}
                a=${a:-0}
                total=$((p + a))
                if [ "$total" -eq 0 ]; then
                    perc="0.00"
                else
                    perc=$(awk "BEGIN {printf \"%.2f\", ($p/$total)*100}")
                fi
                printf "%-5s | %-9s | %6s%% (%d/%d)\n" "$sid" "$sname" "$perc" "$p" "$total"
            done < "$students_file"
            ;;

        7)
            # Defaulter list (below threshold)
            echo "------------- Defaulter List (< $threshold%) -------------"
            ensure_attendance_file
            found=0
            while IFS=',' read -r sid sname || [ -n "$sid" ]; do
                p=$(grep -E ",${sid}," "$attendance_file" 2>/dev/null | grep -c ",P" 2>/dev/null || true)
                a=$(grep -E ",${sid}," "$attendance_file" 2>/dev/null | grep -c ",A" 2>/dev/null || true)
                p=${p:-0}
                a=${a:-0}
                total=$((p + a))
                if [ "$total" -eq 0 ]; then
                    perc=0
                else
                    perc=$(awk "BEGIN {printf \"%d\", ($p/$total)*100}")
                fi
                if [ "$perc" -lt "$threshold" ]; then
                    echo "$sid | $sname | $perc% ($p/$total)"
                    found=1
                fi
            done < "$students_file"
            if [ "$found" -eq 0 ]; then
                echo "No defaulters (all students >= $threshold%)."
            fi
            ;;

        8)
            # Alert system: students with 3 consecutive absences
            echo "----- Alert: Students with 3 consecutive absences -----"
            ensure_attendance_file
            any_alert=0
            # We'll sort by date so consecutive means in time order
            if [ ! -f "$attendance_file" ] || [ ! -s "$attendance_file" ]; then
                echo "No attendance records to check."
            else
                while IFS=',' read -r sid sname || [ -n "$sid" ]; do
                    # get statuses for this student ordered by date
                    # format: date,status
                    statuses=$(awk -F, -v id="$sid" '$2==id {print $1","$4}' "$attendance_file" | sort)
                    if [ -z "$statuses" ]; then
                        continue
                    fi
                    # Check for 3 consecutive A
                    consec=0
                    echo "$statuses" | while IFS=',' read -r d st; do
                        if [ "$st" = "A" ]; then
                            consec=$((consec+1))
                        else
                            consec=0
                        fi
                        if [ "$consec" -ge 3 ]; then
                            echo "$sid | $sname has $consec consecutive absences (last on $d)"
                            any_alert=1
                            break
                        fi
                    done
                done < "$students_file"
                if [ "$any_alert" -eq 0 ]; then
                    echo "No students with 3 consecutive absences."
                fi
            fi
            ;;

        9)
            # Add or Remove Student
            echo "1) Add Student"
            echo "2) Remove Student"
            read -p "Choose 1 or 2: " ar_choice
            if [[ "$ar_choice" == "1" ]]; then
                read -p "Enter new Student ID (e.g. S106): " new_id
                read -p "Enter new Student Name: " new_name
                # Check if ID already exists
                if grep -q "^${new_id}," "$students_file"; then
                    echo "A student with ID $new_id already exists."
                else
                    echo "${new_id},${new_name}" >> "$students_file"
                    echo "Student added: $new_id, $new_name"
                fi
            elif [[ "$ar_choice" == "2" ]]; then
                read -p "Remove by: 1) ID 2) Name : " rem_choice
                if [[ "$rem_choice" == "1" ]]; then
                    read -p "Enter Student ID to remove: " rem_id
                    if ! grep -q "^${rem_id}," "$students_file"; then
                        echo "Student ID $rem_id not found."
                    else
                        # Remove from students file
                        awk -F, -v id="$rem_id" '$1!=id' "$students_file" > "${students_file}.tmp" && mv "${students_file}.tmp" "$students_file"
                        echo "Removed student ID $rem_id"
                    fi
                elif [[ "$rem_choice" == "2" ]]; then
                    read -p "Enter Student Name to remove (exact): " rem_name
                    # Remove first exact match (case-insensitive)
                    awk -F, -v name="$rem_name" 'tolower($2)!=tolower(name)' "$students_file" > "${students_file}.tmp" && mv "${students_file}.tmp" "$students_file"
                    echo "Removed students with name matching '$rem_name' (case-insensitive)."
                else
                    echo "Invalid choice for removal."
                fi
            else
                echo "Invalid choice!"
            fi
            ;;

        10)
            echo "Exiting... Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice! Try again."
            ;;
    esac

    echo    # blank line before showing menu again
done
