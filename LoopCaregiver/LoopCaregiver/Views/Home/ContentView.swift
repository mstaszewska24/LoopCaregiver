//
//  ContentView.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 11/12/22.
//

import SwiftUI
import Charts
import CoreData
import LoopKit
import WidgetKit

struct ContentView: View {
    
    @ObservedObject var accountService: AccountServiceManager
    let settings: CaregiverSettings = CaregiverSettings()
    
    init(){
        self.accountService = AccountServiceManager(accountService: CoreDataAccountService(inMemory: false))
    }
    
    var body: some View {
        if let looper = accountService.selectedLooper {
            HomeView(looperService: accountService.createLooperService(looper: looper, settings: settings))
        } else {
            FirstRunView(accountService: accountService, settings: settings, showSheetView: true)
        }
    }
}

struct FirstRunView: View {
    
    @ObservedObject var accountService: AccountServiceManager
    let settings: CaregiverSettings
    @State var showSheetView: Bool = false
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack (path: $path) {
            LooperSetupView(accountService: accountService, settings: settings, path: $path)
        }
    }
}

struct HomeView: View {
    
    @ObservedObject var accountService: AccountServiceManager
    @ObservedObject var remoteDataSource: RemoteDataServiceManager
    @ObservedObject var settings: CaregiverSettings
    @ObservedObject var looperService: LooperService
    
    @State private var showCarbView = false
    @State private var showBolusView = false
    @State private var showOverrideView = false
    @State private var showSettingsView = false
    
    @Environment(\.scenePhase) var scenePhase
    
    init(looperService: LooperService){
        self.looperService = looperService
        self.settings = looperService.settings
        self.accountService = looperService.accountService
        self.remoteDataSource = looperService.remoteDataSource
    }
    
    var body: some View {
        VStack {
            HUDView(looperService: looperService, settings: looperService.settings)
                .padding([.leading, .trailing])
            if let recommendedBolus = remoteDataSource.recommendedBolus {
                TitleSubtitleRowView(title: "Recommended Bolus", subtitle: LocalizationUtils.presentableStringFromBolusAmount(recommendedBolus) + " U")
                    .padding([.bottom, .trailing], 5.0)
            }
            ChartsListView(looperService: looperService, remoteDataSource: remoteDataSource, settings: looperService.settings)
                .padding([.leading, .trailing], 5.0)
            BottomBarView(showCarbView: $showCarbView, showBolusView: $showBolusView, showOverrideView: $showOverrideView, showSettingsView: $showSettingsView, remoteDataSource: remoteDataSource)
        }
        .overlay {
            if !disclaimerValid(){
                disclaimerOverlay()
            }
        }
        .ignoresSafeArea(.keyboard) //Avoid keyboard bounce when popping back from sheets
        .sheet(isPresented: $showCarbView) {
            CarbInputView(looperService: looperService, showSheetView: $showCarbView)
        }
        .sheet(isPresented: $showBolusView) {
            BolusInputView(looperService: looperService, remoteDataSource: looperService.remoteDataSource, showSheetView: $showBolusView)
        }
        .sheet(isPresented: $showOverrideView) {
            NavigationStack {
                OverrideView(delegate: looperService.remoteDataSource) {
                    showOverrideView = false
                }
                .navigationBarTitle(Text("Custom Preset"), displayMode: .inline)
                .navigationBarItems(leading: Button(action: {
                    showOverrideView = false
                }) {
                    Text("Cancel")
                })
            }
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView(looperService: looperService, accountService: accountService, settings: looperService.settings, showSheetView: $showSettingsView)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onOpenURL(perform: { (url) in
            guard let looperId = url.absoluteString.components(separatedBy: "//").last else {
                return
            }
            
            guard let looper = accountService.loopers.first(where: {$0.id == looperId}) else {
                return
            }
            
            if accountService.selectedLooper != looper {
                accountService.selectedLooper = looper
            }
        })
    }
    
    func disclaimerOverlay() -> some View {
        return ZStack {
            Color.cellBackgroundColor
            DisclaimerView()
        }
    }
    
    func disclaimerValid() -> Bool {
        guard let disclaimerAcceptedDate = settings.disclaimerAcceptedDate else {
            return false
        }
        
        return disclaimerAcceptedDate > Date().addingTimeInterval(-60*60*24*365)
    }
}

