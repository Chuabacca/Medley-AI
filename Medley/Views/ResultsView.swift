import SwiftUI

struct ResultsView: View {
    let data: StructuredConsult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header text
                    Text("Here's what we know about your hair so far:")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.brandPrimary)
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                    
                    // Card containing all sections
                    VStack(alignment: .leading, spacing: 0) {
                        // Header section
                        Text("Your Hair")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brandDark)
                            .clipShape(RoundedRectangle(cornerRadius: 16, corners: [.topLeft, .topRight]))
                        
                        // Content sections
                        VStack(alignment: .leading, spacing: 24) {
                            // Hair changes section
                            if hasHairChanges {
                                SectionView(title: "Hair changes") {
                                    if let location = data.hair.changes.location {
                                        ItemView(text: formatHairLocation(location))
                                    }
                                    if let duration = data.hair.changes.duration {
                                        ItemView(text: formatDuration(duration))
                                    }
                                }
                            }
                            
                            // Lifestyle factors section
                            if hasLifestyleFactors {
                                SectionView(title: "Lifestyle factors") {
                                    if let familyHistory = data.lifestyle.family_history {
                                        ItemView(text: "Family history: \(formatYesNo(familyHistory))")
                                    }
                                    if let stress = data.lifestyle.stress {
                                        ItemView(text: "Stress: \(formatStress(stress))")
                                    }
                                }
                            }
                            
                            // Hair routine section
                            if hasHairRoutine {
                                SectionView(title: "Hair routine") {
                                    if let careTime = data.routine.care_time {
                                        ItemView(text: formatCareTime(careTime))
                                    }
                                    ItemView(text: "No styling")
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, corners: [.bottomLeft, .bottomRight]))
                    }
                    .shadow(color: Color.cardShadow, radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    
                    // Raw JSON data section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Raw Data")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(prettyPrintedJSON)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .init(horizontal: .leading, vertical: .top))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.backgroundWarm)
            .navigationTitle("Consultation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.black)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.black)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
            }
        }
    }
    
    // MARK: - Computed properties
    
    private var prettyPrintedJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let jsonData = try? encoder.encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    private var hasHairChanges: Bool {
        data.hair.changes.location != nil || 
        data.hair.changes.amount != nil || 
        data.hair.changes.duration != nil
    }
    
    private var hasLifestyleFactors: Bool {
        data.lifestyle.family_history != nil || data.lifestyle.stress != nil
    }
    
    private var hasHairRoutine: Bool {
        data.routine.care_time != nil
    }
    
    // MARK: - Formatters
    
    private func formatHairLocation(_ location: String) -> String {
        switch location {
        case "hairline": return "At the top"
        case "crown": return "At the crown"
        case "diffuse": return "All over"
        default: return location.capitalized
        }
    }
    
    private func formatDuration(_ duration: String) -> String {
        switch duration {
        case "over_1y": return "Noticed over a year ago"
        case "past_1y": return "Noticed in the past year"
        case "past_few_months": return "Noticed in the past few months"
        case "unsure": return "Not sure when noticed"
        default: return duration
        }
    }
    
    private func formatYesNo(_ value: String) -> String {
        switch value {
        case "yes": return "Yes"
        case "no": return "No"
        case "unsure": return "Not sure"
        default: return value.capitalized
        }
    }
    
    private func formatStress(_ stress: String) -> String {
        switch stress {
        case "all_time": return "All the time"
        case "sometimes": return "Sometimes"
        case "rarely": return "Rarely"
        case "unsure": return "Not sure"
        default: return stress.capitalized
        }
    }
    
    private func formatCareTime(_ time: String) -> String {
        switch time {
        case "lt_5": return "Less than 5 minutes"
        case "5_10": return "5-10 minutes"
        case "gt_10": return "10+ minutes"
        default: return time
        }
    }
}

// MARK: - Supporting Views

struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
            
            VStack(alignment: .leading, spacing: 4) {
                content
            }
        }
    }
}

struct ItemView: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color.brandPrimary)
                .frame(width: 3, height: 20)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Color.brandPrimary)
        }
    }
}

// Custom shape for selective corner rounding
struct RoundedRectangle: Shape {
    var cornerRadius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ResultsView(data: StructuredConsult(
        hair: StructuredConsult.Hair(
            changes: StructuredConsult.Hair.Changes(
                location: "crown",
                amount: "some",
                duration: "over_1y"
            ),
            pattern: "crown",
            type: "straight_wavy",
            length: "short"
        ),
        lifestyle: StructuredConsult.Lifestyle(
            family_history: "yes",
            stress: "rarely"
        ),
        routine: StructuredConsult.Routine(care_time: "lt_10"),
        goals: StructuredConsult.Goals(treatment: ["hairline", "thicker"])
    ))
}
