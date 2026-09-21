//
//  PlayerView.swift
//  naqaa
//
//  Created by Mazen on 30/08/2026.
//

import SwiftUI
import Foundation

struct PlayerView: View {
    let playerState: PlayerState
    
    var body: some View {
        VStack(spacing: 24) {
            
            
            
            
            Text(playerState.selectedSurah?.displayName ?? "")
                .font(.title2)
                .bold()
                .fontWidth(.expanded)
            
            Text(playerState.selectedReciter.reciter.name)
                .foregroundStyle(.secondary)
            
            PlayerProgressBar(progress: playerState.progress)
                .padding(.horizontal)
            
            HStack {
                Text(formattedTime(playerState.player.currentTime))
                Spacer()
                Text(formattedTime(playerState.player.duration))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            
            HStack(spacing: 32) {
                Button {
                    playerState.playPrevious()
                } label: {
                    DirectionalImage("backward.fill")
                        .font(.title3)
                }
                
                Button {
                    playerState.togglePlayPause()
                } label: {
                    if playerState.isBuffering {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        DirectionalImage(playerState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: playerState.isPlaying)
                .accessibilityLabel(
                    playerState.isBuffering
                    ? "Buffering"
                    : (playerState.isPlaying ? "Pause" : "Play")
                )
                
                Button {
                    playerState.playNext()
                } label: {
                    DirectionalImage("forward.fill")
                        .font(.title3)
                }
            }
            .disabled(playerState.isEmpty)
        }
        .buttonStyle(.plain)
        .padding()
    }
    
    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remaining = totalSeconds % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", remaining))"
        }
        return "\(minutes):\(String(format: "%02d", remaining))"
    }
}

#Preview {
    PlayerView(playerState: PlayerState())
      
}
