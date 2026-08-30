import Foundation

extension String {
    func searchKey() -> String {
           let lower = self.lowercased()
           let separators = CharacterSet(charactersIn: " -'.,").union(.whitespaces)
           let noSep = lower.unicodeScalars
               .filter { !separators.contains($0) }
               .map { String($0) }.joined()
           let decomposed = noSep.decomposedStringWithCanonicalMapping
           let stripped = decomposed.unicodeScalars
               .filter {
                   let cat = $0.properties.generalCategory
                   return cat != .nonspacingMark
                       && cat != .spacingMark
                       && cat != .enclosingMark
               }
               .map { String($0) }.joined()
           var arabic = stripped
for (from, target) in [("ة", "ه"), ("ى", "ي"), ("ـ", "")] {
                arabic = arabic.replacingOccurrences(of: from, with: target)
            }
           // Latin consonant skeleton: drop vowels
           let vowels = CharacterSet(charactersIn: "aeiou")
           let skeleton = arabic.unicodeScalars
               .filter { !vowels.contains($0) }
               .map { String($0) }.joined()
           return skeleton
       }
}
