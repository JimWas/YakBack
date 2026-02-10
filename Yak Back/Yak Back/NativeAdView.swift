//
//  NativeAdView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/2/26.
//

import SwiftUI
import Combine
import GoogleMobileAds

// MARK: - Native Ad Loader

class NativeAdViewModel: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published var nativeAd: NativeAd?
    private var adLoader: AdLoader?
    private let adUnitID: String = {
#if DEBUG
        return "ca-app-pub-3940256099942544/3986624511"
#else
        return "ca-app-pub-3057383894764696/5067079401"
#endif
    }()

    func loadAd() {
        guard adLoader == nil || !adLoader!.isLoading else { return }

        adLoader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        adLoader?.delegate = self
        adLoader?.load(Request())
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("Native ad failed to load: \(error.localizedDescription)")
    }
}

// MARK: - Native Ad SwiftUI View

struct AdBannerView: View {
    var showAd: Bool = true
    @StateObject private var viewModel = NativeAdViewModel()

    var body: some View {
        Group {
            if showAd, let nativeAd = viewModel.nativeAd {
                NativeAdRepresentable(nativeAd: nativeAd)
                    .frame(height: 100)
            }
        }
        .onAppear {
            if showAd {
                viewModel.loadAd()
            }
        }
    }
}

// MARK: - UIViewRepresentable Wrapper

struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> GoogleMobileAds.NativeAdView {
        let adView = GoogleMobileAds.NativeAdView()
        adView.backgroundColor = UIColor(MatrixTheme.cardBackground)
        adView.layer.cornerRadius = 12
        adView.layer.borderWidth = 0.5
        adView.layer.borderColor = UIColor(MatrixTheme.cardBorder).cgColor
        adView.clipsToBounds = true

        // Icon
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 6
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(iconView)
        adView.iconView = iconView

        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = UIFont(name: "Nasalization", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold)
        headlineLabel.textColor = UIColor(MatrixTheme.green)
        headlineLabel.numberOfLines = 1
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel

        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = UIFont(name: "Nasalization", size: 9) ?? .systemFont(ofSize: 9)
        bodyLabel.textColor = UIColor(MatrixTheme.dimGreen)
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel

        // CTA Button
        var ctaConfig = UIButton.Configuration.filled()
        ctaConfig.baseBackgroundColor = UIColor(MatrixTheme.green)
        ctaConfig.baseForegroundColor = .black
        ctaConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont(name: "Nasalization", size: 10) ?? .systemFont(ofSize: 10, weight: .semibold)
            return outgoing
        }
        ctaConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        ctaConfig.cornerStyle = .medium
        let ctaButton = UIButton(configuration: ctaConfig)
        ctaButton.isUserInteractionEnabled = false
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(ctaButton)
        adView.callToActionView = ctaButton

        // Ad label
        let adLabel = UILabel()
        adLabel.text = "Ad"
        adLabel.font = .systemFont(ofSize: 9, weight: .bold)
        adLabel.textColor = UIColor(MatrixTheme.background)
        adLabel.backgroundColor = UIColor(MatrixTheme.dimGreen)
        adLabel.textAlignment = .center
        adLabel.layer.cornerRadius = 3
        adLabel.clipsToBounds = true
        adLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adLabel)

        // Layout
        NSLayoutConstraint.activate([
            // Icon: left side, vertically centered
            iconView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 50),
            iconView.heightAnchor.constraint(equalToConstant: 50),

            // Ad label: top-left corner of icon
            adLabel.topAnchor.constraint(equalTo: iconView.topAnchor, constant: -4),
            adLabel.leadingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -4),
            adLabel.widthAnchor.constraint(equalToConstant: 20),
            adLabel.heightAnchor.constraint(equalToConstant: 14),

            // Headline: right of icon, top area
            headlineLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            headlineLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 14),
            headlineLabel.trailingAnchor.constraint(lessThanOrEqualTo: ctaButton.leadingAnchor, constant: -8),

            // Body: below headline
            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.trailingAnchor.constraint(lessThanOrEqualTo: ctaButton.leadingAnchor, constant: -8),

            // CTA: right side, vertically centered
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            ctaButton.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
        ])

        return adView
    }

    func updateUIView(_ adView: GoogleMobileAds.NativeAdView, context: Context) {
        adView.nativeAd = nativeAd

        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction?.uppercased(), for: .normal)

        adView.callToActionView?.isHidden = nativeAd.callToAction == nil
    }
}
