//
//  ContentView.swift
//  Shared
//
//  Created by Baye Wayly on 2021/2/24.
//

import CoreData
import SwiftUI

struct UsageItem: Identifiable {
  var id: String {
    compactCommand
  }

  var totalInBytes: UInt64
  var totalOutBytes: UInt64
  var inCount: UInt64
  var outCount: UInt64
  var compactCommand: String
  var pid: Int
}

typealias StringError = String
extension StringError: Identifiable {
  public var id: Self { self }
}

class AppState: ObservableObject {
  var task: Process? = nil
  
  enum DaemonState {
    case stopped, running
  }
  
  var items = [String: UsageItem]()
  
  @Published var items: [UsageItem] = []
  @Published var state: DaemonState = .stopped
  @Published var lastError: StringError? = nil
  
  func process(line: String) {
    let columns = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    
    guard columns.count > 2, columns[1].hasPrefix("PgIn") || columns[1].hasPrefix("PgOut") else {
      return
    }
    
    if line.range(of: "/VM/swapfile") == nil {
      return
    }
    
    print(line)
    guard let cmd = columns.last?.components(separatedBy: "."), cmd.count == 2, let pid = Int(cmd[1]) else {
      return
    }
    
    var command: String = cmd[0]
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
//      let lines = output.components(separatedBy: .newlines)
      
//      guard let range = output.rangeOfCharacter(from: .newlines) else {
//        lineBuffer += output
//        return
//      }
//
//      let line = lineBuffer + output[..<range.lowerBound]
//      self.process(line: line)
//      lineBuffer = String(output[range.upperBound..<output.endIndex])
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
  
  var body: some View {
    List {
      HStack(alignment: .center, spacing: 10) {
        Text("Process")
          .frame(width: 120, alignment: .leading)

        Divider()

        Text("Swap In")
          .frame(width: 60, alignment: .leading)
        Divider()

        Text("Swap Out")
          .frame(width: 60, alignment: .leading)
        Divider()

        Text("In Count")
          .frame(width: 60, alignment: .leading)

        Divider()

        Text("Out Count")
          .frame(width: 60, alignment: .leading)
      }
      .font(.footnote)
      .foregroundColor(.secondary)

      ForEach(state.items) { item in
        HStack(alignment: .center, spacing: 10) {
          Text(item.compactCommand)
            .frame(width: 120, alignment: .leading)
          Divider()

          Text(item.totalInBytes.description)
            .frame(width: 60, alignment: .leading)
          Divider()

          Text(item.totalOutBytes.description)
            .frame(width: 60, alignment: .leading)
          Divider()

          Text(item.inCount.description)
            .frame(width: 60, alignment: .leading)
          Divider()

          Text(item.outCount.description)
            .frame(width: 60, alignment: .leading)
        }
      }
      .font(.system(.subheadline, design: .monospaced))
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

private let itemFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
  return formatter
}()

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
