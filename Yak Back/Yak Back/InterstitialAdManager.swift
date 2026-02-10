//
//  InterstitialAdManager.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/10/26.
//

import Foundation
import GoogleMobileAds
import UIKit
import Combine

@MainActor
final class InterstitialAdManager: NSObject, FullScreenContentDelegate, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    private let adUnitID: String = {
#if DEBUG
        return "ca-app-pub-3940256099942544/4411468910"
#else
        return "ca-app-pub-3057383894764696/6392942820"
#endif
    }()
    private var interstitial: InterstitialAd?
    private var isLoading = false

    func loadAd() {
        weak let weakSelf = self
        guard !isLoading, interstitial == nil else { return }
        isLoading = true
        InterstitialAd.load(with: adUnitID, request: Request()) { ad, error in
            // Hop back to the main actor without capturing mutable self in a concurrently-executing context.
            Task { @MainActor in
                guard let strongSelf = weakSelf else { return }
                strongSelf.isLoading = false
                if let error {
                    print("Interstitial failed to load: \(error.localizedDescription)")
                    return
                }
                strongSelf.interstitial = ad
                strongSelf.interstitial?.fullScreenContentDelegate = strongSelf
            }
        }
    }

    func showIfAvailable() {
        guard let interstitial else {
            loadAd()
            return
        }

        guard let rootVC = topViewController() else {
            loadAd()
            return
        }

        interstitial.present(from: rootVC)
        self.interstitial = nil
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Interstitial failed to present: \(error.localizedDescription)")
        loadAd()
    }

    // MARK: - Top VC Helper

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        return keyWindow?.rootViewController?.topMost()
    }
}

private extension UIViewController {
    func topMost() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMost()
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMost()
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMost()
        }
        return self
    }
}

