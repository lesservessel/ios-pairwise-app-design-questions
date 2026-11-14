import Foundation

enum Gaussian {
    static func pdf(_ x: Double) -> Double {
        exp(-0.5 * x * x) / (2 * Double.pi).squareRoot()
    }

    static func cdf(_ x: Double) -> Double {
        0.5 * (1 + erf(x / 2.0.squareRoot()))
    }
}
