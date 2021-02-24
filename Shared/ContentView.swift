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

struct ContentView: View {
  enum DaemonState {
    case stopped, running
  }

  @State private var state: DaemonState = .stopped
  @State private var items: [UsageItem] = [
    UsageItem(totalInBytes: 1024*1024*4, totalOutBytes: 1024*1024*33, inCount: 1000, outCount: 2000, compactCommand: "kernel_task", pid: 1)
  ]

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

      ForEach(items) { item in
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
    .toolbar {
      if state == .stopped {
        Button(action: {}) {
          Label("Start", systemImage: "play.circle")
        }
      } else {
        Button(action: {}) {
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
