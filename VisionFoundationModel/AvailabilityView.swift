import SwiftUI
import FoundationModels

struct AvailabilityView: View {
    private var model = SystemLanguageModel.default
    
    var body: some View {
        switch model.availability {
        case .available:
            MainView()
            
        case .unavailable(.modelNotReady):
            Text("The model is not yet ready. Please try again later.")
            
        case .unavailable(.appleIntelligenceNotEnabled):
            Text("Apple Intelligence is not enabled on this device.")
            
        case .unavailable(.deviceNotEligible):
            Text("This device is not supported by Apple Intelligence.")
            
        case .unavailable(let other):
            Text("An unknown error has occurred.：\(String(describing: other))")
        }
    }
}
