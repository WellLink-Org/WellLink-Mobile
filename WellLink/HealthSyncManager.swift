// HealthSyncManager.swift
// Same as your original, but now:
//   • Uses Auth0 user ID instead of hard-coded "user_123"
//   • Injects a Bearer token on every backend request
//   • Reads backendURL from Auth0Config

import HealthKit
import UserNotifications
import BackgroundTasks

class HealthSyncManager {

    static let shared = HealthSyncManager()
    private init() {}

    let healthStore = HKHealthStore()

    // Reads the URL from the central config (no more hard-coded string here)
    private var backendURL: String { Auth0Config.backendBase + "/api/health" }

    // MARK: - Notification Permission
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            print(granted ? "Notifications allowed" : "Notifications denied")
        }
    }

    // MARK: - Schedule Weekly Sync (every Monday at 8am)
    func scheduleWeeklySync() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["weekly-health-sync"]
        )

        let content       = UNMutableNotificationContent()
        content.title     = "Weekly Health Sync"
        content.body      = "Tap to sync your last 7 days of health data."
        content.sound     = .default

        var dateComponents    = DateComponents()
        dateComponents.weekday = 2  // Monday
        dateComponents.hour    = 8
        dateComponents.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly-health-sync", content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Notification schedule failed: \(error)") }
        }
    }

    // MARK: - Background Task Handler
    func handleBackgroundSync(task: BGAppRefreshTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        requestPermissionsAndSync(daysBack: 7) { success in
            task.setTaskCompleted(success: success)
            self.scheduleBackgroundTask()
        }
    }

    func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yourname.healthsync.weeklysync")
        request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Permissions + Full Sync
    func requestPermissionsAndSync(daysBack: Int, completion: @escaping (Bool) -> Void) {
        var typesToRead = Set<HKObjectType>()

        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .stepCount, .distanceWalkingRunning, .distanceCycling, .distanceSwimming,
            .distanceWheelchair, .pushCount, .swimmingStrokeCount, .flightsClimbed,
            .activeEnergyBurned, .basalEnergyBurned, .appleExerciseTime,
            .appleMoveTime, .appleStandTime, .heartRate, .restingHeartRate,
            .heartRateVariabilitySDNN, .walkingHeartRateAverage,
            .heartRateRecoveryOneMinute, .bodyMass, .bodyMassIndex,
            .bodyFatPercentage, .height, .leanBodyMass, .waistCircumference,
            .respiratoryRate, .oxygenSaturation, .vo2Max, .bodyTemperature,
            .bloodPressureSystolic, .bloodPressureDiastolic, .bloodGlucose,
            .walkingSpeed, .walkingStepLength, .walkingAsymmetryPercentage,
            .walkingDoubleSupportPercentage, .stairAscentSpeed, .stairDescentSpeed,
            .appleWalkingSteadiness, .environmentalAudioExposure, .headphoneAudioExposure,
            .dietaryEnergyConsumed, .dietaryCarbohydrates, .dietaryFiber,
            .dietarySugar, .dietaryFatTotal, .dietaryProtein, .dietaryVitaminC,
            .dietaryVitaminD, .dietaryCalcium, .dietaryIron, .dietarySodium,
            .dietaryWater, .dietaryCaffeine, .electrodermalActivity,
        ]
        for id in quantityIdentifiers {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { typesToRead.insert(t) }
        }

        let categoryIdentifiers: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis, .appleStandHour, .mindfulSession,
            .highHeartRateEvent, .lowHeartRateEvent, .irregularHeartRhythmEvent,
            .headphoneAudioExposureEvent, .handwashingEvent, .toothbrushingEvent,
            .menstrualFlow, .ovulationTestResult, .cervicalMucusQuality,
            .sexualActivity, .pregnancy, .lactation,
            .fatigue, .headache, .nausea, .fever, .chills, .coughing,
            .soreThroat, .shortnessOfBreath, .dizziness,
            .generalizedBodyAche, .sleepChanges, .lossOfSmell, .lossOfTaste,
        ]
        for id in categoryIdentifiers {
            if let t = HKCategoryType.categoryType(forIdentifier: id) { typesToRead.insert(t) }
        }
        typesToRead.insert(HKObjectType.workoutType())

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            guard success else {
                print("Auth failed: \(error?.localizedDescription ?? "")")
                completion(false)
                return
            }
            self.fetchAndSend(daysBack: daysBack, completion: completion)
        }
    }

    // MARK: - Fetch + Send
    private func fetchAndSend(daysBack: Int, completion: @escaping (Bool) -> Void) {
        let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
        let end   = Date()
        let group = DispatchGroup()

        // ── Use the real Auth0 userId, not "user_123" ──────────────────────
        let userId = AuthManager.shared.currentUser?.id ?? "anonymous"
        var result: [String: Any] = ["userId": userId]

        let quantityFetches: [(String, HKQuantityTypeIdentifier, HKUnit)] = [
            ("steps",                  .stepCount,                    .count()),
            ("distanceWalkingRunning", .distanceWalkingRunning,       .meter()),
            ("distanceCycling",        .distanceCycling,              .meter()),
            ("distanceSwimming",       .distanceSwimming,             .meter()),
            ("flightsClimbed",         .flightsClimbed,               .count()),
            ("pushCount",              .pushCount,                    .count()),
            ("swimmingStrokes",        .swimmingStrokeCount,          .count()),
            ("activeEnergy",           .activeEnergyBurned,           .kilocalorie()),
            ("basalEnergy",            .basalEnergyBurned,            .kilocalorie()),
            ("exerciseMinutes",        .appleExerciseTime,            .minute()),
            ("standMinutes",           .appleStandTime,               .minute()),
            ("heartRate",              .heartRate,                    HKUnit(from: "count/min")),
            ("restingHeartRate",       .restingHeartRate,             HKUnit(from: "count/min")),
            ("hrv",                    .heartRateVariabilitySDNN,     .secondUnit(with: .milli)),
            ("walkingHeartRate",       .walkingHeartRateAverage,      HKUnit(from: "count/min")),
            ("oxygenSaturation",       .oxygenSaturation,             .percent()),
            ("respiratoryRate",        .respiratoryRate,              HKUnit(from: "count/min")),
            ("bodyTemperature",        .bodyTemperature,              .degreeCelsius()),
            ("bloodGlucose",           .bloodGlucose,                 HKUnit(from: "mg/dL")),
            ("bloodPressureSystolic",  .bloodPressureSystolic,        .millimeterOfMercury()),
            ("bloodPressureDiastolic", .bloodPressureDiastolic,       .millimeterOfMercury()),
            ("weight",                 .bodyMass,                     .gramUnit(with: .kilo)),
            ("bmi",                    .bodyMassIndex,                .count()),
            ("bodyFat",                .bodyFatPercentage,            .percent()),
            ("height",                 .height,                       .meter()),
            ("leanBodyMass",           .leanBodyMass,                 .gramUnit(with: .kilo)),
            ("waistCircumference",     .waistCircumference,           .meter()),
            ("walkingSpeed",           .walkingSpeed,                 HKUnit(from: "m/s")),
            ("walkingStepLength",      .walkingStepLength,            .meter()),
            ("walkingAsymmetry",       .walkingAsymmetryPercentage,   .percent()),
            ("vo2Max",                 .vo2Max,                       HKUnit(from: "ml/kg·min")),
            ("environmentalAudio",     .environmentalAudioExposure,   .decibelAWeightedSoundPressureLevel()),
            ("headphoneAudio",         .headphoneAudioExposure,       .decibelAWeightedSoundPressureLevel()),
            ("dietaryCalories",        .dietaryEnergyConsumed,        .kilocalorie()),
            ("dietaryCarbs",           .dietaryCarbohydrates,         .gram()),
            ("dietaryProtein",         .dietaryProtein,               .gram()),
            ("dietaryFat",             .dietaryFatTotal,              .gram()),
            ("dietaryFiber",           .dietaryFiber,                 .gram()),
            ("dietarySugar",           .dietarySugar,                 .gram()),
            ("dietarySodium",          .dietarySodium,                .gram()),
            ("dietaryWater",           .dietaryWater,                 .liter()),
            ("dietaryCaffeine",        .dietaryCaffeine,              .gram()),
            ("dietaryCalcium",         .dietaryCalcium,               .gram()),
            ("dietaryIron",            .dietaryIron,                  .gram()),
            ("dietaryVitaminC",        .dietaryVitaminC,              .gram()),
            ("dietaryVitaminD",        .dietaryVitaminD,              .gram()),
        ]

        for (key, id, unit) in quantityFetches {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { continue }
            group.enter()
            fetchQuantity(type: type, unit: unit, start: start, end: end) { samples in
                result[key] = samples; group.leave()
            }
        }

        let categoryFetches: [(String, HKCategoryTypeIdentifier)] = [
            ("sleep",                    .sleepAnalysis),
            ("mindfulMinutes",           .mindfulSession),
            ("standHours",               .appleStandHour),
            ("highHeartRateEvents",      .highHeartRateEvent),
            ("lowHeartRateEvents",       .lowHeartRateEvent),
            ("irregularHeartEvents",     .irregularHeartRhythmEvent),
            ("handwashing",              .handwashingEvent),
            ("toothbrushing",            .toothbrushingEvent),
            ("symptomFatigue",           .fatigue),
            ("symptomHeadache",          .headache),
            ("symptomNausea",            .nausea),
            ("symptomFever",             .fever),
            ("symptomChills",            .chills),
            ("symptomCoughing",          .coughing),
            ("symptomSoreThroat",        .soreThroat),
            ("symptomShortnessOfBreath", .shortnessOfBreath),
            ("symptomDizziness",         .dizziness),
            ("symptomBodyAche",          .generalizedBodyAche),
            ("symptomSleepChanges",      .sleepChanges),
            ("symptomLossOfSmell",       .lossOfSmell),
            ("symptomLossOfTaste",       .lossOfTaste),
            ("menstrualFlow",            .menstrualFlow),
            ("ovulationTest",            .ovulationTestResult),
            ("cervicalMucus",            .cervicalMucusQuality),
            ("sexualActivity",           .sexualActivity),
            ("pregnancy",                .pregnancy),
            ("lactation",                .lactation),
        ]

        for (key, id) in categoryFetches {
            guard let type = HKCategoryType.categoryType(forIdentifier: id) else { continue }
            group.enter()
            fetchCategory(type: type, start: start, end: end) { samples in
                result[key] = samples; group.leave()
            }
        }

        group.enter()
        fetchWorkouts(start: start, end: end) { workouts in
            result["workouts"] = workouts; group.leave()
        }

        group.notify(queue: .global()) {
            self.send(payload: result, completion: completion)
        }
    }

    // MARK: - Generic Fetchers (unchanged from original)
    private func fetchQuantity(type: HKQuantityType, unit: HKUnit,
                                start: Date, end: Date,
                                completion: @escaping ([[String: Any]]) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort      = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query     = HKSampleQuery(
            sampleType: type, predicate: predicate,
            limit: HKObjectQueryNoLimit, sortDescriptors: [sort]
        ) { _, samples, _ in
            let data = (samples as? [HKQuantitySample])?.map { s -> [String: Any] in
                ["timestamp": ISO8601DateFormatter().string(from: s.startDate),
                 "value":     s.quantity.doubleValue(for: unit),
                 "source":    s.sourceRevision.source.name]
            } ?? []
            completion(data)
        }
        healthStore.execute(query)
    }

    private func fetchCategory(type: HKCategoryType, start: Date, end: Date,
                                completion: @escaping ([[String: Any]]) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort      = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query     = HKSampleQuery(
            sampleType: type, predicate: predicate,
            limit: HKObjectQueryNoLimit, sortDescriptors: [sort]
        ) { _, samples, _ in
            let data = (samples as? [HKCategorySample])?.map { s -> [String: Any] in
                ["start":           ISO8601DateFormatter().string(from: s.startDate),
                 "end":             ISO8601DateFormatter().string(from: s.endDate),
                 "value":           s.value,
                 "durationMinutes": Int(s.endDate.timeIntervalSince(s.startDate) / 60),
                 "source":          s.sourceRevision.source.name]
            } ?? []
            completion(data)
        }
        healthStore.execute(query)
    }

    private func fetchWorkouts(start: Date, end: Date,
                                completion: @escaping ([[String: Any]]) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query     = HKSampleQuery(
            sampleType: HKObjectType.workoutType(), predicate: predicate,
            limit: HKObjectQueryNoLimit, sortDescriptors: nil
        ) { _, samples, _ in
            let data = (samples as? [HKWorkout])?.map { w -> [String: Any] in
                ["type":            w.workoutActivityType.name,
                 "start":           ISO8601DateFormatter().string(from: w.startDate),
                 "end":             ISO8601DateFormatter().string(from: w.endDate),
                 "durationMinutes": Int(w.duration / 60),
                 "calories":        Int(w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0),
                 "distanceKm":      w.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0,
                 "source":          w.sourceRevision.source.name]
            } ?? []
            completion(data)
        }
        healthStore.execute(query)
    }

    // MARK: - Send to Backend (with access token)
    private func send(payload: [String: Any], completion: @escaping (Bool) -> Void) {
        AuthManager.shared.freshAccessToken { tokenResult in
            switch tokenResult {
            case .failure:
                print("No valid auth token, skipping sync")
                completion(false)

            case .success(let token):
                guard let url  = URL(string: self.backendURL),
                      let body = try? JSONSerialization.data(withJSONObject: payload) else {
                    completion(false); return
                }
                var req = URLRequest(url: url)
                req.httpMethod  = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(token)",  forHTTPHeaderField: "Authorization")
                req.httpBody    = body

                URLSession.shared.dataTask(with: req) { _, response, error in
                    let ok = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
                    print(ok ? "Sync sent ✓" : "Sync failed: \(error?.localizedDescription ?? "")")
                    completion(ok)
                }.resume()
            }
        }
    }
}

// MARK: - HKWorkoutActivityType names (unchanged)
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running:                      return "Running"
        case .walking:                      return "Walking"
        case .cycling:                      return "Cycling"
        case .swimming:                     return "Swimming"
        case .yoga:                         return "Yoga"
        case .functionalStrengthTraining:   return "Strength Training"
        case .highIntensityIntervalTraining:return "HIIT"
        case .hiking:                       return "Hiking"
        case .dance:                        return "Dance"
        case .pilates:                      return "Pilates"
        case .rowing:                       return "Rowing"
        case .elliptical:                   return "Elliptical"
        case .stairClimbing:                return "Stair Climbing"
        case .tennis:                       return "Tennis"
        case .basketball:                   return "Basketball"
        case .soccer:                       return "Soccer"
        case .golf:                         return "Golf"
        case .snowboarding:                 return "Snowboarding"
        case .boxing:                       return "Boxing"
        case .kickboxing:                   return "Kickboxing"
        case .martialArts:                  return "Martial Arts"
        case .crossTraining:                return "Cross Training"
        case .jumpRope:                     return "Jump Rope"
        default:                            return "Other (\(rawValue))"
        }
    }
}
