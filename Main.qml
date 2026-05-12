import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Qt.labs.settings 1.0

MainView {
    id: root
    objectName: "mainView"
    applicationName: "studybuddy"
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    property bool darkMode: false
    property string userName: ""
    property string userCourse: ""
    property string userCollege: ""
    property string userGoal: ""

    property int completedTasks: 0
    property int totalTasks: 0
    property int studySessionSeconds: 0
    property bool studyRunning: false
    property string statusMessage: "Ready to plan"
    property string rewardMessage: ""

    property string newTaskTitle: ""
    property string newTaskDue: "Today"
    property string newTaskPriority: "Medium"
    property string taskSearchText: ""
    property string notesText: ""

    property string newScheduleTime: ""
    property string newScheduleSubject: ""
    property string newScheduleNote: ""
    property string newScheduleReminderMinutes: "10"

    property bool profileWasSaved: false
    property bool profileEditedSinceSave: false

    property bool activeReminderVisible: false
    property string activeReminderText: ""

    property bool showSplash: true

    property string odooServerUrl: "https://studybuddy0.odoo.com"
    property string odooDatabase: "studybuddy0"
    property string odooUsername: "kulkarnikanak0@gmail.com"
    property string odooPassword: ""
    property string odooStatus: "Not connected"
    property bool odooBusy: false
    property int odooUid: 0

    Settings {
        id: appSettings
        property bool savedDarkMode: false
        property string savedUserName: ""
        property string savedUserCourse: ""
        property string savedUserCollege: ""
        property string savedUserGoal: ""
        property string savedTasksJson: "[]"
        property string savedSchedulesJson: "[]"
        property int savedStudySessionSeconds: 0
        property string savedNotesText: ""
        property string savedOdooServerUrl: "https://studybuddy0.odoo.com"
        property string savedOdooDatabase: "studybuddy0"
        property string savedOdooUsername: "kulkarnikanak0@gmail.com"
        property string savedOdooPassword: ""
    }

    ListModel { id: taskModel }
    ListModel { id: scheduleModel }

    Component.onCompleted: {
        darkMode = appSettings.savedDarkMode
        userName = appSettings.savedUserName
        userCourse = appSettings.savedUserCourse
        userCollege = appSettings.savedUserCollege
        userGoal = appSettings.savedUserGoal
        studySessionSeconds = appSettings.savedStudySessionSeconds
        notesText = appSettings.savedNotesText

        odooServerUrl = appSettings.savedOdooServerUrl
        odooDatabase = appSettings.savedOdooDatabase
        odooUsername = appSettings.savedOdooUsername
        odooPassword = appSettings.savedOdooPassword

        restoreTaskModel(appSettings.savedTasksJson)
        restoreScheduleModel(appSettings.savedSchedulesJson)
        refreshTaskStats()

        profileWasSaved = userName.trim().length > 0 ||
                          userCourse.trim().length > 0 ||
                          userCollege.trim().length > 0 ||
                          userGoal.trim().length > 0
        profileEditedSinceSave = false

        if (taskModel.count === 0)
            statusMessage = "Add your first task"

        stack.push(homePage)
        checkScheduleReminders()
        splashTimer.start()
    }

    Timer {
        id: splashTimer
        interval: 1800
        repeat: false
        onTriggered: root.showSplash = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.studyRunning
        onTriggered: {
            if (!root.studyRunning)
                return
            root.studySessionSeconds++
            if (root.studySessionSeconds > 0 && root.studySessionSeconds % 1500 === 0) {
                rewardMessage = "25-minute study milestone. Take a short break."
                statusMessage = rewardMessage
                saveState()
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.checkScheduleReminders()
    }

    function pad2(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function formatDuration(totalSeconds) {
        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor((totalSeconds % 3600) / 60)
        var seconds = totalSeconds % 60
        if (hours > 0)
            return hours + ":" + pad2(minutes) + ":" + pad2(seconds)
        return minutes + ":" + pad2(seconds)
    }

    function greetingText() {
        var hour = new Date().getHours()
        if (hour >= 5 && hour < 12) return "Good morning"
        if (hour >= 12 && hour < 17) return "Good afternoon"
        if (hour >= 17 && hour < 22) return "Good evening"
        return "Good night"
    }

    function displayName() {
        var name = userName.trim()
        return name.length > 0 ? name : "there"
    }

    function titleText() {
        return darkMode ? "#FFFFFF" : "#3b2058"
    }

    function softText() {
        return darkMode ? "#d8ddff" : "#5e4a79"
    }

    function cardBg() {
        return darkMode ? "#16192f" : "#ffffff"
    }

    function cardBorder() {
        return darkMode ? "#2d3158" : "#d3b1ea"
    }

    function pageBgTop() {
        return darkMode ? "#0f1226" : "#f7f1ff"
    }

    function pageBgBottom() {
        return darkMode ? "#1c1f3a" : "#dcbcf6"
    }

    function priorityColor(priority) {
        if (priority === "High") return "#ff6b6b"
        if (priority === "Low") return "#4caf50"
        return "#7c8cff"
    }

    function prioritySurface(priority) {
        if (priority === "High") return darkMode ? "#3b1f28" : "#ffe8e8"
        if (priority === "Low") return darkMode ? "#173528" : "#e6fff0"
        return darkMode ? "#1d2445" : "#edf0ff"
    }

    function taskProgressPercent() {
        if (totalTasks <= 0)
            return 0
        return Math.round((completedTasks / totalTasks) * 100)
    }

    function showReminder(text) {
        activeReminderText = text
        activeReminderVisible = true
        statusMessage = text
    }

    function dismissReminder() {
        activeReminderVisible = false
        activeReminderText = ""
    }

    function parseReminderMinutes(valueText) {
        var minutes = parseInt(valueText)
        if (isNaN(minutes) || minutes < 1)
            minutes = 10
        return minutes
    }

    function checkScheduleReminders() {
        var now = new Date().getTime()
        var triggeredText = ""

        for (var i = 0; i < scheduleModel.count; ++i) {
            var item = scheduleModel.get(i)
            if (!item.reminded && item.remindAt > 0 && now >= item.remindAt) {
                scheduleModel.setProperty(i, "reminded", true)
                triggeredText = "Reminder: " + item.subject
                if (item.time.length > 0)
                    triggeredText += " at " + item.time
                if (item.note && item.note.length > 0)
                    triggeredText += " - " + item.note
                showReminder(triggeredText)
                break
            }
        }

        if (triggeredText.length > 0)
            saveState()
    }

    function taskModelToJson() {
        var arr = []
        for (var i = 0; i < taskModel.count; ++i) {
            var item = taskModel.get(i)
            arr.push({
                title: item.title,
                due: item.due,
                priority: item.priority,
                done: item.done
            })
        }
        return JSON.stringify(arr)
    }

    function scheduleModelToJson() {
        var arr = []
        for (var i = 0; i < scheduleModel.count; ++i) {
            var item = scheduleModel.get(i)
            arr.push({
                time: item.time,
                subject: item.subject,
                note: item.note,
                remindAt: item.remindAt,
                reminderMinutes: item.reminderMinutes,
                reminded: item.reminded
            })
        }
        return JSON.stringify(arr)
    }

    function restoreTaskModel(jsonText) {
        taskModel.clear()
        var arr = []
        try { arr = JSON.parse(jsonText) } catch (e) { arr = [] }
        for (var i = 0; i < arr.length; ++i) {
            var t = arr[i]
            taskModel.append({
                title: t.title || "Task",
                due: t.due || "Today",
                priority: t.priority || "Medium",
                done: !!t.done
            })
        }
    }

    function restoreScheduleModel(jsonText) {
        scheduleModel.clear()
        var arr = []
        try { arr = JSON.parse(jsonText) } catch (e) { arr = [] }
        for (var i = 0; i < arr.length; ++i) {
            var s = arr[i]
            scheduleModel.append({
                time: s.time || "",
                subject: s.subject || "Class",
                note: s.note || "",
                remindAt: s.remindAt || 0,
                reminderMinutes: s.reminderMinutes || 10,
                reminded: !!s.reminded
            })
        }
    }

    function refreshTaskStats() {
        totalTasks = taskModel.count
        var done = 0
        for (var i = 0; i < taskModel.count; ++i) {
            if (taskModel.get(i).done)
                done++
        }
        completedTasks = done
    }

    function profileButtonText() {
        if (profileWasSaved && profileEditedSinceSave)
            return "Update Profile"
        if (profileWasSaved)
            return "Saved"
        return "Save Profile"
    }

    function markProfileEdited() {
        profileEditedSinceSave = true
    }

    function saveState() {
        appSettings.savedDarkMode = darkMode
        appSettings.savedUserName = userName
        appSettings.savedUserCourse = userCourse
        appSettings.savedUserCollege = userCollege
        appSettings.savedUserGoal = userGoal
        appSettings.savedTasksJson = taskModelToJson()
        appSettings.savedSchedulesJson = scheduleModelToJson()
        appSettings.savedStudySessionSeconds = studySessionSeconds
        appSettings.savedNotesText = notesText
        appSettings.savedOdooServerUrl = odooServerUrl
        appSettings.savedOdooDatabase = odooDatabase
        appSettings.savedOdooUsername = odooUsername
        appSettings.savedOdooPassword = odooPassword
    }

    function saveProfile() {
        saveState()
        profileWasSaved = true
        profileEditedSinceSave = false
        statusMessage = "Profile saved"
    }

    function startStudy() {
        if (studyRunning)
            return
        studyRunning = true
        statusMessage = "Study timer started"
        saveState()
    }

    function stopStudy() {
        if (!studyRunning)
            return
        studyRunning = false
        statusMessage = "Study timer paused"
        saveState()
    }

    function resetStudy() {
        studyRunning = false
        studySessionSeconds = 0
        rewardMessage = ""
        statusMessage = "Study timer reset"
        saveState()
    }

    function completeAllTasks() {
        if (taskModel.count === 0) {
            statusMessage = "No tasks to complete"
            return
        }
        for (var i = 0; i < taskModel.count; ++i)
            taskModel.setProperty(i, "done", true)
        refreshTaskStats()
        rewardMessage = "All tasks complete. Reward unlocked: take a 10-minute break."
        statusMessage = rewardMessage
        saveState()
    }

    function addTask() {
        var title = newTaskTitle.trim()
        if (title.length === 0) {
            statusMessage = "Enter a task title"
            return
        }
        taskModel.append({
            title: title,
            due: newTaskDue.trim().length > 0 ? newTaskDue.trim() : "Today",
            priority: newTaskPriority,
            done: false
        })
        newTaskTitle = ""
        newTaskDue = "Today"
        newTaskPriority = "Medium"
        rewardMessage = ""
        statusMessage = "Task added"
        refreshTaskStats()
        saveState()
    }

    function toggleTask(index) {
        var item = taskModel.get(index)
        var wasDone = !!item.done
        taskModel.setProperty(index, "done", !wasDone)
        refreshTaskStats()
        if (completedTasks === totalTasks && totalTasks > 0) {
            rewardMessage = "All tasks complete. Reward unlocked: take a 10-minute break."
            statusMessage = rewardMessage
        } else if (!wasDone && taskModel.get(index).done) {
            rewardMessage = "Task completed. Reward unlocked: short break."
            statusMessage = rewardMessage
        } else {
            rewardMessage = ""
            statusMessage = "Task updated"
        }
        saveState()
    }

    function removeTask(index) {
        taskModel.remove(index)
        refreshTaskStats()
        if (completedTasks === totalTasks && totalTasks > 0) {
            rewardMessage = "All tasks complete. Reward unlocked: take a 10-minute break."
            statusMessage = rewardMessage
        } else if (totalTasks === 0) {
            rewardMessage = ""
            statusMessage = "Task list is empty"
        } else {
            rewardMessage = ""
            statusMessage = "Task removed"
        }
        saveState()
    }

    function addSchedule() {
        var timeText = newScheduleTime.trim()
        var subjectText = newScheduleSubject.trim()
        var noteText = newScheduleNote.trim()
        var reminderMinutes = parseReminderMinutes(newScheduleReminderMinutes)

        if (timeText.length === 0 || subjectText.length === 0) {
            statusMessage = "Enter schedule time and subject"
            return
        }

        scheduleModel.append({
            time: timeText,
            subject: subjectText,
            note: noteText,
            remindAt: new Date().getTime() + (reminderMinutes * 60000),
            reminderMinutes: reminderMinutes,
            reminded: false
        })

        newScheduleTime = ""
        newScheduleSubject = ""
        newScheduleNote = ""
        newScheduleReminderMinutes = "10"
        statusMessage = "Schedule added. Reminder set."
        saveState()
    }

    function removeSchedule(index) {
        scheduleModel.remove(index)
        statusMessage = scheduleModel.count === 0 ? "No schedules yet" : "Schedule removed"
        saveState()
    }

    function clearAllData() {
        taskModel.clear()
        scheduleModel.clear()
        completedTasks = 0
        totalTasks = 0
        studySessionSeconds = 0
        studyRunning = false
        rewardMessage = ""
        dismissReminder()
        statusMessage = "All data cleared"
        saveState()
    }

    function normalizeOdooUrl(url) {
        var trimmed = (url || "").trim()
        if (trimmed.length === 0)
            return ""
        if (trimmed.indexOf("http://") !== 0 && trimmed.indexOf("https://") !== 0)
            trimmed = "https://" + trimmed
        return trimmed.replace(/\/$/, "")
    }

    function authenticateOdoo(callback) {
        var baseUrl = normalizeOdooUrl(odooServerUrl)

        if (baseUrl.length === 0 || odooDatabase.trim().length === 0 || odooUsername.trim().length === 0 || odooPassword.length === 0) {
            odooStatus = "Fill all Odoo fields first"
            if (callback)
                callback(false, 0)
            return
        }

        odooBusy = true
        odooStatus = "Connecting to Odoo..."

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                odooBusy = false
                try {
                    var response = JSON.parse(xhr.responseText)
                    if (response && response.result && response.result > 0) {
                        odooUid = response.result
                        odooStatus = "Odoo connection successful"
                        if (callback)
                            callback(true, odooUid)
                    } else {
                        odooUid = 0
                        odooStatus = "Odoo authentication failed"
                        if (callback)
                            callback(false, 0)
                    }
                } catch (e) {
                    odooUid = 0
                    odooStatus = "Odoo authentication failed"
                    if (callback)
                        callback(false, 0)
                }
            }
        }

        xhr.onerror = function() {
            odooBusy = false
            odooUid = 0
            odooStatus = "Network error while connecting to Odoo"
            if (callback)
                callback(false, 0)
        }

        xhr.open("POST", baseUrl + "/jsonrpc")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({
            jsonrpc: "2.0",
            method: "call",
            params: {
                service: "common",
                method: "authenticate",
                args: [odooDatabase, odooUsername, odooPassword, {}]
            },
            id: 1
        }))
    }

    function testOdooConnection() {
        authenticateOdoo(function(success, uid) {
            if (success) {
                odooStatus = "Odoo connection successful"
                saveState()
            } else {
                odooStatus = "Odoo authentication failed"
            }
        })
    }

    function syncToOdoo() {
        authenticateOdoo(function(success, uid) {
            if (!success) {
                odooStatus = "Odoo authentication failed"
                return
            }

            var baseUrl = normalizeOdooUrl(odooServerUrl)
            var index = 0
            var synced = 0

            function pushNext() {
                if (index >= taskModel.count) {
                    odooBusy = false
                    odooStatus = "Sync complete. Tasks synced: " + synced
                    saveState()
                    return
                }

                var task = taskModel.get(index)
                index++

                if (!task || !task.title || task.title.trim().length === 0) {
                    pushNext()
                    return
                }

                var xhr = new XMLHttpRequest()
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE) {
                        try {
                            var resp = JSON.parse(xhr.responseText)
                            if (resp && resp.result) {
                                synced++
                            }
                        } catch (e) {
                        }
                        pushNext()
                    }
                }

                xhr.onerror = function() {
                    pushNext()
                }

                xhr.open("POST", baseUrl + "/jsonrpc")
                xhr.setRequestHeader("Content-Type", "application/json")
                xhr.send(JSON.stringify({
                    jsonrpc: "2.0",
                    method: "call",
                    params: {
                        service: "object",
                        method: "execute_kw",
                        args: [
                            odooDatabase,
                            uid,
                            odooPassword,
                            "project.task",
                            "create",
                            [{
                                name: task.title
                            }]
                        ]
                    },
                    id: 2
                }))
            }

            odooBusy = true
            odooStatus = "Syncing local tasks..."
            pushNext()
        })
    }

    PageStack {
        id: stack
        anchors.fill: parent
        anchors.bottomMargin: units.gu(6)
    }

    Rectangle {
        anchors.fill: parent
        z: -1
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.pageBgTop() }
            GradientStop { position: 1.0; color: root.pageBgBottom() }
        }
    }

    Rectangle {
        id: reminderBanner
        visible: root.activeReminderVisible
        z: 2000
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: units.gu(1)
        radius: units.gu(1.2)
        color: root.darkMode ? "#1F2937" : "#FFF7D6"
        border.width: 1
        border.color: root.darkMode ? "#374151" : "#F2D36B"
        opacity: visible ? 1 : 0
        implicitHeight: reminderRow.implicitHeight + units.gu(2)

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        RowLayout {
            id: reminderRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: units.gu(1)
            spacing: units.gu(1)

            Rectangle {
                width: units.gu(4)
                height: units.gu(4)
                radius: units.gu(2)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#FFB347" }
                    GradientStop { position: 1.0; color: "#FF7A59" }
                }

                Label {
                    anchors.centerIn: parent
                    text: "!"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 18
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: units.gu(0.2)

                Label {
                    text: "Reminder"
                    color: root.titleText()
                    font.bold: true
                }

                Label {
                    width: parent.width
                    text: root.activeReminderText
                    color: root.softText()
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                width: units.gu(10)
                height: units.gu(4.2)
                radius: units.gu(0.9)
                color: "#e74c3c"

                Label {
                    anchors.centerIn: parent
                    text: "Dismiss"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismissReminder()
                }
            }
        }
    }

    Rectangle {
        id: bottomNav
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: units.gu(5.5)
        color: root.darkMode ? "#141833" : "#f7efff"
        border.width: 1
        border.color: root.cardBorder()
        z: 1500

        RowLayout {
            anchors.fill: parent
            anchors.margins: units.gu(0.5)
            spacing: units.gu(0.5)

            Repeater {
                model: [
                    { label: "Home", page: homePage },
                    { label: "Tasks", page: taskPage },
                    { label: "Schedule", page: schedulePage },
                    { label: "Notes", page: notesPage },
                    { label: "Analytics", page: analyticsPage },
                    { label: "Settings", page: settingsPage },
                    { label: "Odoo", page: odooPage }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: units.gu(5)
                    radius: units.gu(0.9)
                    color: root.cardBg()
                    border.width: 1
                    border.color: root.cardBorder()

                    Label {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.titleText()
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            stack.clear()
                            stack.push(modelData.page)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        visible: root.showSplash
        z: 3000
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f9f5ff" }
            GradientStop { position: 1.0; color: "#dbc3f7" }
        }

        Column {
            anchors.centerIn: parent
            spacing: units.gu(2)

            Rectangle {
                width: units.gu(24)
                height: units.gu(24)
                radius: units.gu(4)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#ead9ff" }
                    GradientStop { position: 1.0; color: "#c59dff" }
                }
                border.width: 0

                Rectangle {
                    width: units.gu(16)
                    height: units.gu(16)
                    radius: units.gu(3)
                    anchors.centerIn: parent
                    color: "transparent"
                    border.width: 2
                    border.color: "#6f3fbf"

                    Rectangle {
                        width: units.gu(7)
                        height: units.gu(10)
                        x: units.gu(1.8)
                        y: units.gu(2)
                        radius: units.gu(1.6)
                        color: "transparent"
                        border.width: 2
                        border.color: "#6f3fbf"
                    }

                    Rectangle {
                        width: units.gu(7)
                        height: units.gu(10)
                        x: units.gu(7.2)
                        y: units.gu(2)
                        radius: units.gu(1.6)
                        color: "transparent"
                        border.width: 2
                        border.color: "#6f3fbf"
                    }

                    Rectangle {
                        width: units.gu(8)
                        height: units.gu(8)
                        radius: units.gu(4)
                        anchors.centerIn: parent
                        color: "white"
                        border.width: 2
                        border.color: "#6f3fbf"

                        Label {
                            anchors.centerIn: parent
                            text: "SB"
                            color: "#6f3fbf"
                            font.bold: true
                            font.pixelSize: 28
                        }
                    }
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "StudyBuddy"
                font.pixelSize: 30
                font.bold: true
                color: "#4b246f"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Plan smarter. Study better."
                color: "#6a4b8a"
            }
        }
    }

    Component {
        id: homePage
        Page {
            header: PageHeader { title: "StudyBuddy" }

            Flickable {
                anchors.fill: parent
                anchors.bottomMargin: units.gu(8)
                contentWidth: width
                contentHeight: homeColumn.implicitHeight + units.gu(10)
                clip: true

                Column {
                    id: homeColumn
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: units.gu(7)
                    spacing: units.gu(1.6)

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: heroContent.implicitHeight + units.gu(4)

                        Column {
                            id: heroContent
                            width: parent.width - units.gu(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            Label {
                                width: parent.width
                                text: root.greetingText() + ", " + root.displayName()
                                color: root.titleText()
                                font.pixelSize: 24
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                width: parent.width
                                text: root.userGoal.trim().length > 0 ? root.userGoal : "Plan smarter. Study better."
                                color: root.softText()
                                wrapMode: Text.WordWrap
                            }

                            Rectangle {
                                width: parent.width
                                height: units.gu(5)
                                radius: units.gu(1)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: root.studyRunning ? "#ff9800" : "#5c6bc0" }
                                    GradientStop { position: 1.0; color: root.studyRunning ? "#ffb74d" : "#7986cb" }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: root.studyRunning ? "Stop" : "Start"
                                    color: "white"
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.studyRunning ? root.stopStudy() : root.startStudy()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: focusBlock.implicitHeight + units.gu(4)

                        Column {
                            id: focusBlock
                            width: parent.width - units.gu(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            RowLayout {
                                width: parent.width

                                Label {
                                    text: "Study Clock"
                                    color: root.titleText()
                                    font.bold: true
                                    font.pixelSize: 18
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: units.gu(2)
                                    height: units.gu(2)
                                    radius: units.gu(1)
                                    color: root.studyRunning ? "#4caf50" : "#7c8cff"
                                }
                            }

                            Label {
                                width: parent.width
                                text: formatDuration(root.studySessionSeconds)
                                color: root.studyRunning ? "#7c8cff" : root.titleText()
                                font.pixelSize: 32
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: parent.width
                                height: units.gu(1)
                                radius: units.gu(0.5)
                                color: root.darkMode ? "#23284b" : "#efe7fb"

                                Rectangle {
                                    width: parent.width * Math.min(root.studySessionSeconds / 7200, 1)
                                    height: parent.height
                                    radius: units.gu(0.5)
                                    color: root.studyRunning ? "#7c8cff" : "#4caf50"
                                }
                            }

                            RowLayout {
                                width: parent.width
                                spacing: units.gu(1)

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: units.gu(5)
                                    radius: units.gu(1)
                                    color: root.darkMode ? "#23284b" : "#f1e3fb"
                                    border.width: 1
                                    border.color: root.cardBorder()

                                    Label {
                                        anchors.centerIn: parent
                                        text: "Reset"
                                        color: root.softText()
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.resetStudy()
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: units.gu(5)
                                    radius: units.gu(1)
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#4caf50" }
                                        GradientStop { position: 1.0; color: "#6edb84" }
                                    }

                                    Label {
                                        anchors.centerIn: parent
                                        text: "Continue"
                                        color: "white"
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.startStudy()
                                    }
                                }
                            }
                        }
                    }

                    GridLayout {
                        width: parent.width
                        columns: width > units.gu(80) ? 4 : 2
                        columnSpacing: units.gu(1)
                        rowSpacing: units.gu(1)

                        Repeater {
                            model: [
                                { title: "Tasks", value: completedTasks + "/" + totalTasks },
                                { title: "Progress", value: taskProgressPercent() + "%" },
                                { title: "Schedules", value: scheduleModel.count },
                                { title: "Study Time", value: formatDuration(root.studySessionSeconds) }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: units.gu(11)
                                radius: units.gu(1.2)
                                color: root.cardBg()
                                border.width: 1
                                border.color: root.cardBorder()

                                Column {
                                    anchors.centerIn: parent
                                    spacing: units.gu(0.5)

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.title
                                        color: root.softText()
                                        font.pixelSize: 14
                                    }

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.value
                                        color: root.darkMode ? "white" : "#222"
                                        font.pixelSize: 20
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.2)
                        color: root.rewardMessage.length > 0 ? (root.darkMode ? "#244d3c" : "#e5fff1") : (root.darkMode ? "#262b4d" : "#e6c9f6")
                        border.width: root.rewardMessage.length > 0 ? 1 : 0
                        border.color: root.rewardMessage.length > 0 ? "#4caf50" : "transparent"
                        implicitHeight: rewardText.implicitHeight + units.gu(3)

                        Label {
                            id: rewardText
                            width: parent.width - units.gu(3)
                            anchors.centerIn: parent
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            text: root.rewardMessage.length > 0 ? root.rewardMessage : "Complete tasks to unlock rewards"
                            color: root.rewardMessage.length > 0 ? (root.darkMode ? "#d9ffe7" : "#1f5b3f") : (root.darkMode ? "white" : "#4d2868")
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.2)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: statusText.implicitHeight + units.gu(3)

                        Label {
                            id: statusText
                            width: parent.width - units.gu(3)
                            anchors.centerIn: parent
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            text: root.statusMessage
                            color: root.softText()
                        }
                    }

                    Item { width: 1; height: units.gu(4) }
                }
            }
        }
    }

    Component {
        id: taskPage
        Page {
            header: PageHeader { title: "Tasks" }

            Flickable {
                anchors.fill: parent
                anchors.bottomMargin: units.gu(8)
                contentWidth: width
                contentHeight: taskColumn.implicitHeight + units.gu(6)
                clip: true

                Column {
                    id: taskColumn
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: units.gu(3)
                    spacing: units.gu(1.6)

                    Item { width: 1; height: units.gu(1.5) }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.rewardMessage.length > 0 ? (root.darkMode ? "#244d3c" : "#e5fff1") : root.cardBg()
                        border.width: 1
                        border.color: root.rewardMessage.length > 0 ? "#4caf50" : root.cardBorder()
                        implicitHeight: taskBannerText.implicitHeight + units.gu(3)

                        Label {
                            id: taskBannerText
                            width: parent.width - units.gu(3)
                            anchors.centerIn: parent
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            text: root.rewardMessage.length > 0 ? root.rewardMessage : "Add tasks and unlock rewards when you complete them"
                            color: root.rewardMessage.length > 0 ? (root.darkMode ? "#d9ffe7" : "#1f5b3f") : root.softText()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: taskForm.implicitHeight + units.gu(4)

                        Column {
                            id: taskForm
                            width: parent.width - units.gu(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            Label { text: "Add New Task"; color: root.softText(); font.bold: true }

                            TextField {
                                width: parent.width
                                placeholderText: "Task title"
                                text: root.newTaskTitle
                                onTextChanged: root.newTaskTitle = text
                            }

                            TextField {
                                width: parent.width
                                placeholderText: "Due note, e.g. Today, 6 PM"
                                text: root.newTaskDue
                                onTextChanged: root.newTaskDue = text
                            }

                            Label { text: "Priority"; color: root.softText() }

                            RowLayout {
                                width: parent.width
                                spacing: units.gu(0.8)

                                Repeater {
                                    model: ["Low", "Medium", "High"]

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: units.gu(4.4)
                                        radius: units.gu(0.8)
                                        color: root.newTaskPriority === modelData ? root.prioritySurface(modelData) : (root.darkMode ? "#23284b" : "#f1e3fb")
                                        border.width: 1
                                        border.color: root.newTaskPriority === modelData ? root.priorityColor(modelData) : root.cardBorder()

                                        Label {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.newTaskPriority === modelData ? root.priorityColor(modelData) : root.softText()
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.newTaskPriority = modelData
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: units.gu(5)
                                radius: units.gu(1)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#7c8cff" }
                                    GradientStop { position: 1.0; color: "#9aa7ff" }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: "Add Task"
                                    color: "white"
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.addTask()
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: units.gu(1)

                        TextField {
                            width: parent.width
                            placeholderText: "Search tasks..."
                            text: root.taskSearchText
                            onTextChanged: root.taskSearchText = text
                        }

                        Rectangle {
                            width: parent.width
                            height: units.gu(5)
                            radius: units.gu(1)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#4caf50" }
                                GradientStop { position: 1.0; color: "#6edb84" }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: taskModel.count > 0 ? "Mark All Complete & Unlock Reward" : "No Tasks to Complete"
                                color: "white"
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: taskModel.count > 0
                                onClicked: root.completeAllTasks()
                            }
                        }
                    }

                    Label {
                        text: taskModel.count === 0 ? "No tasks yet. Add one above." : "Your tasks"
                        color: root.softText()
                        font.bold: true
                    }

                    Repeater {
                        model: taskModel

                        delegate: Rectangle {
                            visible: root.taskSearchText.length === 0
                                     || title.toLowerCase().indexOf(root.taskSearchText.toLowerCase()) !== -1

                            width: taskColumn.width
                            radius: units.gu(1.2)
                            color: root.cardBg()
                            border.width: 1
                            border.color: done ? "#4caf50" : root.cardBorder()
                            implicitHeight: taskRow.implicitHeight + units.gu(2)

                            RowLayout {
                                id: taskRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: units.gu(1)
                                spacing: units.gu(1)

                                Rectangle {
                                    Layout.preferredWidth: units.gu(4)
                                    Layout.preferredHeight: units.gu(4)
                                    radius: units.gu(2)
                                    color: done ? "#4caf50" : (root.darkMode ? "#23284b" : "#f1e3fb")
                                    border.width: 1
                                    border.color: done ? "#4caf50" : root.cardBorder()

                                    Label {
                                        anchors.centerIn: parent
                                        text: done ? "✓" : ""
                                        color: "white"
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.toggleTask(index)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: units.gu(0.4)

                                    Label {
                                        text: title
                                        color: root.darkMode ? "white" : "#222"
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        opacity: done ? 0.65 : 1.0
                                    }

                                    Label {
                                        text: due
                                        color: root.softText()
                                        wrapMode: Text.WordWrap
                                        opacity: done ? 0.65 : 1.0
                                    }

                                    Rectangle {
                                        width: units.gu(12)
                                        height: units.gu(3)
                                        radius: units.gu(0.8)
                                        color: root.priorityColor(priority)

                                        Label {
                                            anchors.centerIn: parent
                                            text: priority
                                            color: "white"
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: units.gu(4)
                                    Layout.preferredHeight: units.gu(4)
                                    radius: units.gu(0.8)
                                    color: "#e74c3c"

                                    Label {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: "white"
                                        font.pixelSize: 16
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.removeTask(index)
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: units.gu(4) }
                }
            }
        }
    }

    Component {
        id: schedulePage
        Page {
            header: PageHeader { title: "Schedule" }

            Flickable {
                anchors.fill: parent
                anchors.bottomMargin: units.gu(8)
                contentWidth: width
                contentHeight: scheduleColumn.implicitHeight + units.gu(6)
                clip: true

                Column {
                    id: scheduleColumn
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: units.gu(3)
                    spacing: units.gu(1.6)

                    Item { width: 1; height: units.gu(1.5) }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: scheduleForm.implicitHeight + units.gu(4)

                        Column {
                            id: scheduleForm
                            width: parent.width - units.gu(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            Label { text: "Add New Schedule"; color: root.softText(); font.bold: true }

                            TextField {
                                width: parent.width
                                placeholderText: "Time, e.g. 9:00 AM"
                                text: root.newScheduleTime
                                onTextChanged: root.newScheduleTime = text
                            }

                            TextField {
                                width: parent.width
                                placeholderText: "Subject or event"
                                text: root.newScheduleSubject
                                onTextChanged: root.newScheduleSubject = text
                            }

                            TextField {
                                width: parent.width
                                placeholderText: "Note (optional)"
                                text: root.newScheduleNote
                                onTextChanged: root.newScheduleNote = text
                            }

                            TextField {
                                width: parent.width
                                placeholderText: "Reminder in minutes"
                                text: root.newScheduleReminderMinutes
                                inputMethodHints: Qt.ImhDigitsOnly
                                onTextChanged: root.newScheduleReminderMinutes = text
                            }

                            Rectangle {
                                width: parent.width
                                height: units.gu(5)
                                radius: units.gu(1)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#4caf50" }
                                    GradientStop { position: 1.0; color: "#6edb84" }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: "Add Schedule"
                                    color: "white"
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.addSchedule()
                                }
                            }
                        }
                    }

                    Label {
                        text: scheduleModel.count === 0 ? "No schedules yet. Add one above." : "Your schedule"
                        color: root.softText()
                        font.bold: true
                    }

                    Repeater {
                        model: scheduleModel

                        delegate: Rectangle {
                            width: scheduleColumn.width
                            radius: units.gu(1.2)
                            color: root.cardBg()
                            border.width: 1
                            border.color: root.cardBorder()
                            implicitHeight: scheduleRow.implicitHeight + units.gu(2)

                            RowLayout {
                                id: scheduleRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: units.gu(1)
                                spacing: units.gu(1)

                                Rectangle {
                                    Layout.preferredWidth: units.gu(12)
                                    Layout.preferredHeight: units.gu(4)
                                    radius: units.gu(0.8)
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#7c8cff" }
                                        GradientStop { position: 1.0; color: "#9aa7ff" }
                                    }

                                    Label {
                                        anchors.centerIn: parent
                                        text: time
                                        color: "white"
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: units.gu(0.3)

                                    Label {
                                        text: subject
                                        color: root.darkMode ? "white" : "#222"
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                    }

                                    Label {
                                        text: note.length > 0 ? note : "No note added"
                                        color: root.softText()
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                    }

                                    Label {
                                        text: reminded ? "Reminder delivered" : ("Reminder in " + reminderMinutes + " min")
                                        color: root.softText()
                                        font.pixelSize: 12
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: units.gu(4)
                                    Layout.preferredHeight: units.gu(4)
                                    radius: units.gu(0.8)
                                    color: "#e74c3c"

                                    Label {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: "white"
                                        font.pixelSize: 16
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.removeSchedule(index)
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: units.gu(4) }
                }
            }
        }
    }

    Component {
        id: notesPage

        Page {
            header: PageHeader { title: "Notes" }

            Column {
                anchors.fill: parent
                anchors.margins: units.gu(2)
                spacing: units.gu(1)

                Label {
                    text: "Quick Notes"
                    color: root.titleText()
                    font.bold: true
                    font.pixelSize: 22
                }

                TextArea {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: units.gu(50)

                    text: root.notesText
                    placeholderText: "Write your notes here..."

                    onTextChanged: {
                        root.notesText = text
                        root.saveState()
                    }
                }

                Label {
                    text: "Notes auto-saved"
                    color: root.softText()
                    font.pixelSize: 12
                }
            }
        }
    }

    Component {
        id: analyticsPage

        Page {
            header: PageHeader { title: "Analytics" }

            Flickable {
                anchors.fill: parent
                anchors.bottomMargin: units.gu(8)
                contentWidth: width
                contentHeight: analyticsColumn.implicitHeight + units.gu(5)
                clip: true

                Column {
                    id: analyticsColumn
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: units.gu(3)
                    spacing: units.gu(1.6)

                    Item { width: 1; height: units.gu(1.5) }

                    Label {
                        text: "Study Analytics"
                        font.pixelSize: 24
                        color: root.titleText()
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: graphBlock.implicitHeight + units.gu(4)

                        Column {
                            id: graphBlock
                            width: parent.width - units.gu(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            Label {
                                text: "Real Analytics Graph"
                                color: root.softText()
                                font.bold: true
                            }

                            RowLayout {
                                width: parent.width
                                height: units.gu(24)
                                spacing: units.gu(1)

                                Repeater {
                                    model: [
                                        { label: "Tasks", value: completedTasks, max: Math.max(totalTasks, 1), color: "#7c8cff" },
                                        { label: "Progress", value: taskProgressPercent(), max: 100, color: "#4caf50" },
                                        { label: "Schedules", value: scheduleModel.count, max: Math.max(scheduleModel.count, 1), color: "#ff9800" },
                                        { label: "Study Hrs", value: Math.round(root.studySessionSeconds / 3600), max: Math.max(Math.round(root.studySessionSeconds / 3600), 1), color: "#ab47bc" }
                                    ]

                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: units.gu(0.7)

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                height: parent.height * Math.min(modelData.value / modelData.max, 1)
                                                radius: units.gu(0.8)
                                                color: modelData.color
                                            }
                                        }

                                        Label {
                                            text: modelData.label
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: root.softText()
                                            font.pixelSize: 12
                                        }

                                        Label {
                                            text: modelData.value.toString()
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: root.titleText()
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: summaryBlock.implicitHeight + units.gu(4)

                        Column {
                            id: summaryBlock
                            width: parent.width - units.gu(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            Label { text: "Completion"; color: root.softText(); font.bold: true }
                            Label {
                                text: root.taskProgressPercent() + "% Completed"
                                color: root.titleText()
                                font.pixelSize: 26
                                font.bold: true
                            }
                            Label {
                                text: "Tasks done: " + completedTasks + " of " + totalTasks
                                color: root.softText()
                            }
                            Label {
                                text: "Study time: " + formatDuration(root.studySessionSeconds)
                                color: root.softText()
                            }
                            Label {
                                text: root.rewardMessage.length > 0 ? root.rewardMessage : "Rewards unlock when you finish tasks or reach a study milestone."
                                color: root.softText()
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Item { width: 1; height: units.gu(4) }
                }
            }
        }
    }

    Component {
        id: settingsPage
        Page {
            header: PageHeader { title: "Settings" }

            Flickable {
                anchors.fill: parent
                anchors.bottomMargin: units.gu(8)
                contentWidth: width
                contentHeight: settingsColumn.implicitHeight + units.gu(5)
                clip: true

                Column {
                    id: settingsColumn
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: units.gu(3)
                    spacing: units.gu(1.6)

                    Item { width: 1; height: units.gu(1.5) }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: profileHero.implicitHeight + units.gu(4)

                        Column {
                            id: profileHero
                            width: parent.width
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            Rectangle {
                                width: units.gu(12)
                                height: units.gu(12)
                                radius: units.gu(6)
                                anchors.horizontalCenter: parent.horizontalCenter
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#7c8cff" }
                                    GradientStop { position: 1.0; color: "#9aa7ff" }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: displayName().length > 0 ? displayName().charAt(0).toUpperCase() : "S"
                                    font.pixelSize: 32
                                    color: "white"
                                    font.bold: true
                                }
                            }

                            Label {
                                width: parent.width
                                text: displayName()
                                color: root.darkMode ? "white" : "#222"
                                font.pixelSize: 22
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Label {
                                width: parent.width
                                text: userCourse.trim().length > 0 ? userCourse : "Add your course in profile"
                                color: root.softText()
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: themeBox.implicitHeight + units.gu(4)

                        Column {
                            id: themeBox
                            width: parent.width - units.gu(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            Label {
                                text: "Theme"
                                color: root.softText()
                                font.bold: true
                            }

                            Rectangle {
                                width: parent.width
                                height: units.gu(5)
                                radius: units.gu(1)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: root.darkMode ? "#555" : "#7c8cff" }
                                    GradientStop { position: 1.0; color: root.darkMode ? "#777" : "#9aa7ff" }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: root.darkMode ? "Switch to Light Mode" : "Switch to Dark Mode"
                                    color: "white"
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.darkMode = !root.darkMode
                                        root.statusMessage = root.darkMode ? "Dark mode enabled" : "Light mode enabled"
                                        root.saveState()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: profileForm.implicitHeight + units.gu(4)

                        Column {
                            id: profileForm
                            width: parent.width - units.gu(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: units.gu(2)
                            spacing: units.gu(1)

                            Label { text: "Profile"; color: root.softText(); font.bold: true }

                            TextField {
                                width: parent.width
                                placeholderText: "Your name"
                                text: root.userName
                                onTextChanged: { root.userName = text; root.markProfileEdited(); root.saveState() }
                            }

                            TextField {
                                width: parent.width
                                placeholderText: "Example: BTech CSE"
                                text: root.userCourse
                                onTextChanged: { root.userCourse = text; root.markProfileEdited(); root.saveState() }
                            }

                            TextField {
                                width: parent.width
                                placeholderText: "College name"
                                text: root.userCollege
                                onTextChanged: { root.userCollege = text; root.markProfileEdited(); root.saveState() }
                            }

                            TextField {
                                width: parent.width
                                placeholderText: "Example: Finish 2 tasks today"
                                text: root.userGoal
                                onTextChanged: { root.userGoal = text; root.markProfileEdited(); root.saveState() }
                            }

                            Rectangle {
                                width: parent.width
                                height: units.gu(5)
                                radius: units.gu(1)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#4caf50" }
                                    GradientStop { position: 1.0; color: "#6edb84" }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: root.profileButtonText()
                                    color: "white"
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.saveProfile()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.2)
                        color: root.darkMode ? "#262b4d" : "#e6c9f6"
                        implicitHeight: settingsMsg.implicitHeight + units.gu(3)

                        Label {
                            id: settingsMsg
                            width: parent.width - units.gu(3)
                            anchors.centerIn: parent
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            text: root.displayName().length > 0 ? greetingText() + ", " + displayName() : "Fill your profile to personalize StudyBuddy"
                            color: root.darkMode ? "white" : "#4d2868"
                        }
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.5)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: odooHint.implicitHeight + units.gu(3)

                        Label {
                            id: odooHint
                            width: parent.width - units.gu(3)
                            anchors.centerIn: parent
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            text: "Open Odoo Sync from the bottom bar to connect and sync tasks"
                            color: root.softText()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: units.gu(5)
                        radius: units.gu(1)
                        color: "#e74c3c"

                        Label {
                            anchors.centerIn: parent
                            text: "Clear All Data"
                            color: "white"
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.clearAllData()
                        }
                    }

                    Item { width: 1; height: units.gu(4) }
                }
            }
        }
    }

    Component {
        id: odooPage
        Page {
            header: PageHeader { title: "Odoo Sync" }

            Flickable {
                anchors.fill: parent
                anchors.bottomMargin: units.gu(8)
                contentWidth: width
                contentHeight: odooColumn.implicitHeight + units.gu(6)
                clip: true

                Column {
                    id: odooColumn
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: units.gu(3)
                    spacing: units.gu(1.4)

                    Item { width: 1; height: units.gu(1.5) }

                    Label {
                        text: "Remote Sync"
                        color: root.titleText()
                        font.bold: true
                        font.pixelSize: 22
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "Odoo Server URL"
                        text: root.odooServerUrl
                        onTextChanged: root.odooServerUrl = text
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "Database"
                        text: root.odooDatabase
                        onTextChanged: root.odooDatabase = text
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "Username / Email"
                        text: root.odooUsername
                        onTextChanged: root.odooUsername = text
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "Password or API key"
                        echoMode: TextInput.Password
                        text: root.odooPassword
                        onTextChanged: root.odooPassword = text
                    }

                    Button {
                        text: "Test Connection"
                        width: parent.width
                        onClicked: root.testOdooConnection()
                    }

                    Button {
                        text: "Sync Local Tasks"
                        width: parent.width
                        onClicked: root.syncToOdoo()
                    }

                    Rectangle {
                        width: parent.width
                        radius: units.gu(1.2)
                        color: root.cardBg()
                        border.width: 1
                        border.color: root.cardBorder()
                        implicitHeight: odooStatusLabel.implicitHeight + units.gu(3)

                        Label {
                            id: odooStatusLabel
                            width: parent.width - units.gu(3)
                            anchors.centerIn: parent
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            text: root.odooBusy ? "Working..." : root.odooStatus
                            color: root.softText()
                        }
                    }
                }
            }
        }
    }
}