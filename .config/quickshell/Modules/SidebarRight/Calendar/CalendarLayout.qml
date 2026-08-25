pragma Singleton
import Quickshell

/**
 * Builds the 6x7 day grid shown by the calendar widget.
 */

Singleton {
    id: root

    // MONDAY IS THE FIRST DAY OF THE WEEK :HESRIGHTYOUKNOW:
    readonly property var weekDays: [
        { day: 'Mo', today: 0 },
        { day: 'Tu', today: 0 },
        { day: 'We', today: 0 },
        { day: 'Th', today: 0 },
        { day: 'Fr', today: 0 },
        { day: 'Sa', today: 0 },
        { day: 'Su', today: 0 },
    ]

    /**
     * Number of days in a 1-based month. Values outside 1-12 wrap into the
     * adjacent year, so month-1 and month+1 need no special casing.
     * @param { number } month
     * @param { number } year
     * @returns { number }
     */
    function getMonthDays(month, year) {
        // Day 0 of the following month is the last day of this one
        return new Date(year, month, 0).getDate();
    }

    /**
     * Returns the first day of the month x months from now.
     * @param { number } x
     * @returns { Date }
     */
    function getDateInXMonthsTime(x) {
        var currentDate = new Date();
        if (x == 0) return currentDate;

        var targetMonth = currentDate.getMonth() + x;
        var targetYear = currentDate.getFullYear();

        targetYear += Math.floor(targetMonth / 12);
        targetMonth = (targetMonth % 12 + 12) % 12;

        return new Date(targetYear, targetMonth, 1);
    }

    /**
     * Returns 6 rows of 7 day tiles. `today` is 1 for the highlighted day,
     * 0 for other days of the viewed month, and -1 for adjacent-month filler.
     * @param { Date } dateObject
     * @param { boolean } highlight
     * @returns { Array }
     */
    function getCalendarLayout(dateObject, highlight) {
        if (!dateObject) dateObject = new Date();
        const weekday = (dateObject.getDay() + 6) % 7; // MONDAY IS THE FIRST DAY OF THE WEEK
        const day = dateObject.getDate();
        const month = dateObject.getMonth() + 1;
        const year = dateObject.getFullYear();
        const weekdayOfMonthFirst = (weekday + 35 - (day - 1)) % 7;
        const daysInMonth = root.getMonthDays(month, year);
        const daysInNextMonth = root.getMonthDays(month + 1, year);
        const daysInPrevMonth = root.getMonthDays(month - 1, year);

        // Fill
        var monthDiff = (weekdayOfMonthFirst == 0 ? 0 : -1);
        var toFill, dim;
        if (weekdayOfMonthFirst == 0) {
            toFill = 1;
            dim = daysInMonth;
        }
        else {
            toFill = (daysInPrevMonth - (weekdayOfMonthFirst - 1));
            dim = daysInPrevMonth;
        }
        var calendar = [...Array(6)].map(() => Array(7));
        var i = 0, j = 0;
        while (i < 6 && j < 7) {
            calendar[i][j] = {
                "day": toFill,
                "today": ((toFill == day && monthDiff == 0 && highlight) ? 1 : (
                    monthDiff == 0 ? 0 :
                        -1
                ))
            };
            // Increment
            toFill++;
            if (toFill > dim) { // Next month?
                monthDiff++;
                if (monthDiff == 0)
                    dim = daysInMonth;
                else if (monthDiff == 1)
                    dim = daysInNextMonth;
                toFill = 1;
            }
            // Next tile
            j++;
            if (j == 7) {
                j = 0;
                i++;
            }

        }
        return calendar;
    }
}
