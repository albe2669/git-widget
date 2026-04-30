import WidgetKit
import core

struct PREntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct PRTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PREntry {
        PREntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PREntry) -> Void) {
        completion(PREntry(date: Date(), snapshot: try? AppGroupStorage.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PREntry>) -> Void) {
        let snapshot = try? AppGroupStorage.load()
        let entry = PREntry(date: Date(), snapshot: snapshot)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
