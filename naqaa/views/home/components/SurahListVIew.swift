
import SwiftUI

struct SurahListVIew: View{
    @State private var surahViewModel = ViewModel()
    
    var body: some View{
        Group {
            switch surahViewModel.state {
            case .idle:
                Text("No Surahs")
            case .loading:
                ProgressView()
            case .loaded(let surahs):
                LazyVStack(alignment: .leading, spacing: 24) {
                    let surahs = surahViewModel.filteredSurahs
                    ForEach(Array(surahs.enumerated()), id: \.element.id) { index, surah in
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(surah.displayName).font(.headline)
                                .fontWeight(.semibold)
                            HStack {
                                Text(LocalizedStringResource("versesCount", defaultValue: "\(surah.totalVerses) verses"))
                                Divider().overlay(Color.white)
                                Text(surah.revelationPlace.label)
                                
                            }
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        }
                        
                        
                        if index < surahs.count - 1 {
                            Divider().overlay(Color.white.opacity(0.4))
                        }
                        
                        
                        
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .searchable(text: $surahViewModel.query)
                
                
                
            case .error(let error):
                Text(error)
            }
        }
        .task {
            surahViewModel.loadLocal()
        }
    }
    
}



#Preview {
    ZStack{
        SurahListVIew()
        
    }
}
