import Foundation

/**
 Explore structured concurrency in Swift
 https://developer.apple.com/videos/play/wwdc2021/10134/
 */

final class Fetcher {
    
    func fetchDate() async -> Date {
        let timeout = UInt32.random(in: 2...4)
        sleep(timeout)
        
        return Date()
    }

    func fetchMeta(date: Date) async -> String {
        let timeout = UInt32.random(in: 1...3)
        sleep(timeout)
        
        return date.description
    }
}

final class Sample {
    
    
    /// Plain async await
    func fetch_0() async {
        let fetcher = Fetcher()
        
        let date = await fetcher.fetchDate()
        let meta = await fetcher.fetchMeta(date: date)
        
        print(date.timeIntervalSince1970)
        print(meta)
    }
    
    /// Async let
    func fetch_1() async {
        let fetcher = Fetcher()
        
        async let date = fetcher.fetchDate()
        /**
         Perform taks until result needed
         */
        await print(date.timeIntervalSince1970)
        
        let meta = await fetcher.fetchMeta(date: date)
        print(meta)
    }
}

Task {
    let sample = Sample()
    await sample.fetch_0()
    await sample.fetch_1()
}

