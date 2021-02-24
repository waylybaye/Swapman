//
//  ContentView.swift
//  Shared
//
//  Created by Baye Wayly on 2021/2/24.
//

import Combine
import CoreData
import SwiftUI

struct UsageItem: Identifiable {
  var id: String {
    compactCommand
  }

  var totalInBytes: UInt64 = 0
  var totalOutBytes: UInt64 = 0
  var inCount: UInt64 = 0
  var outCount: UInt64 = 0
  var compactCommand: String
  var pid: Int
}

typealias StringError = String
extension StringError: Identifiable {
  public var id: Self { self }
}

class AppState: ObservableObject {
  var task: Process?
  
  enum DaemonState {
    case stopped, running
  }
  
  var items = [String: UsageItem]()
  
  @Published var sortedItems: [UsageItem] = []
  @Published var state: DaemonState = .stopped
  @Published var lastError: StringError? = nil
  
  var lastRefreshAt = Date()
  
  func process(line: String) {
    let columns = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    
    guard columns.count > 2, columns[1].hasPrefix("PgIn") || columns[1].hasPrefix("PgOut") else {
      return
    }
    
    if line.range(of: "/VM/swapfile") == nil {
      return
    }
    
    guard let wIndex = columns.firstIndex(of: "W") else {
      print("warning: can't find W column: ", line)
      return
    }
    
    let process = columns[columns.index(after: wIndex)...].joined(separator: " ")
    let cmd = process.components(separatedBy: ".")
    
    guard cmd.count >= 2, let pid = Int(cmd.last!) else {
      return
    }
    
    let command: String = cmd.prefix(cmd.count - 1).joined(separator: ".")
    var bytes: UInt64 = 0
    var isIn = true
        
    for column in columns {
      if column.hasPrefix("PgIn") {
        isIn = true
      } else if column.hasPrefix("PgOut") {
        isIn = false
      }
      
      if column.hasPrefix("B=") {
        let bytesHex = column[column.index(column.startIndex, offsetBy: 2)...]
        let scanner = Scanner(string: String(bytesHex))
        scanner.scanHexInt64(&bytes)
      }
    }
    
    var item: UsageItem
    
    if items[command] == nil {
      item = UsageItem(compactCommand: command, pid: pid)

    } else {
      item = items[command]!
    }
    
    if isIn {
      item.totalInBytes += bytes
      item.inCount += 1
    } else {
      item.totalOutBytes += bytes
      item.outCount += 1
    }
    
    items[command] = item
    
    if Date().timeIntervalSince(lastRefreshAt) > 0.5 {
      DispatchQueue.main.sync {
        let all = self.items.values.sorted(by: { $0.totalOutBytes > 0 || $1.totalOutBytes > 0 ? $0.totalOutBytes >= $1.totalOutBytes : $0.totalInBytes > $1.totalInBytes })
//      self.sortedItems = all.prefix(50).map{ $0 }
        self.sortedItems = all
        self.lastRefreshAt = Date()
      }
    }
  }
  
  func runFsUsage() {
    let task = Process()
    let pipe = Pipe()
    let stderr = Pipe()
    task.standardOutput = pipe
    task.standardError = stderr
    task.arguments = ["-w", "-f", "filesys,diskio"]
    task.launchPath = "/usr/bin/fs_usage"
    task.launch()

    self.state = .running
    
    var lineBuffer = ""
    
    pipe.fileHandleForReading.readabilityHandler = { fileHandler in
      guard let task = self.task, task.isRunning else {
        return
      }
      
      let data = fileHandler.availableData
      guard data.count > 0, let output = String(data: data, encoding: .utf8) else {
        return
      }
      
      for indice in output.indices {
        if output[indice] == "\n" {
          self.process(line: lineBuffer)
          lineBuffer = ""
        } else {
          lineBuffer += String(output[indice])
        }
      }
    }
    
    task.terminationHandler = { process in
      if let stderr = process.standardError as? Pipe {
        let data = stderr.fileHandleForReading.readDataToEndOfFile()
        DispatchQueue.main.async {
          self.state = .stopped
          
          if data.count > 0 {
            self.lastError = String(data: data, encoding: .utf8)
          }
        }
      }
    }
    self.task = task
  }
  
  func stop() {
    if let task = task, task.isRunning {
      task.terminate()
    }
  }
}

struct ContentView: View {
  @StateObject var state = AppState()
  
  var formatter: ByteCountFormatter {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = .useAll
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter
  }
  
  var header: some View {
    HStack(alignment: .center, spacing: 10) {
      Text("Process")
        .frame(width: 200, alignment: .leading)

      Divider()

      Text("Swap In")
        .frame(width: 80, alignment: .trailing)
      Divider()

      Text("Swap Out")
        .frame(width: 80, alignment: .trailing)
      Divider()

      Text("In Page")
        .frame(width: 60, alignment: .trailing)

      Divider()

      Text("Out Page")
        .frame(width: 60, alignment: .trailing)
    }
    .font(.footnote)
    .foregroundColor(.secondary)
  }
  
  var body: some View {
    List {
      Section(header: header) {
        ForEach(state.sortedItems) { item in
          HStack(alignment: .center, spacing: 10) {
            Text(item.compactCommand)
              .frame(width: 200, alignment: .leading)
            Divider()

            Text(item.totalInBytes > 0 ? formatter.string(fromByteCount: Int64(item.totalInBytes)) : "")
              .frame(width: 80, alignment: .trailing)
            Divider()

            Text(item.totalOutBytes > 0 ? formatter.string(fromByteCount: Int64(item.totalOutBytes)) : "")
              .frame(width: 80, alignment: .trailing)
            Divider()

            Text(item.inCount.description)
              .frame(width: 60, alignment: .trailing)
            Divider()

            Text(item.outCount.description)
              .frame(width: 60, alignment: .trailing)
          }
        }
        .font(.system(.subheadline, design: .monospaced))
      }
    }
    .alert(item: $state.lastError) { error in
      Alert(title: Text(verbatim: error))
    }
    .toolbar {
      if state.state == .stopped {
        Button(action: state.runFsUsage) {
          Label("Start", systemImage: "play.circle")
        }
      } else {
        Button(action: state.stop) {
          Label("Stop", systemImage: "stop.circle")
            .foregroundColor(.accentColor)
        }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
