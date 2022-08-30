//
//  Copyright © Saurabh Sharan. All rights reserved.
//

import Foundation

func deg2rad(_ number: Float) -> CGFloat {
    return CGFloat(number * .pi / 180)
}

// https://victorqi.gitbooks.io/swift-algorithm/content/greatest_common_divisor.html
func gcd(_ a: Int, _ b: Int) -> Int {
    let r = a % b
    if r != 0 {
        return gcd(b, r)
    } else {
        return b
    }
}

class RandomFloatGenerator {
    private var png: Xoroshiro256StarStar

    init(seed: UInt32) {
        self.png = Xoroshiro256StarStar(seed: (seed, seed, seed, seed))
    }

    func randomFloat(min: Float, max: Float) -> Float {
        let f = Float(self.png.next()) / 0xFFFFFFFF
        return f * (max - min) + min
    }
}

// All code below from https://forums.swift.org/t/deterministic-randomness-in-swift/20835/6 , but replaced UInt64 with UInt32

protocol PseudoRandomGenerator: RandomNumberGenerator {
    associatedtype State
    init(seed: State)
    init<Source: RandomNumberGenerator>(from source: inout Source)
}

extension PseudoRandomGenerator {
    init() {
        var source = SystemRandomNumberGenerator()
        self.init(from: &source)
    }
}

private func rotl(_ x: UInt32, _ k: UInt32) -> UInt32 {
    return (x << k) | (x >> (64 &- k))
}

struct Xoroshiro256StarStar {
    typealias State = (UInt32, UInt32, UInt32, UInt32)
    var state: State

    init(seed: State) {
        precondition(seed != (0, 0, 0, 0))
        state = seed
    }

    init<Source: RandomNumberGenerator>(from source: inout Source) {
        repeat {
            state = (source.next(), source.next(), source.next(), source.next())
        } while state == (0, 0, 0, 0)
    }

    mutating func next() -> UInt32 {
        let result = rotl(state.1 &* 5, 7) &* 9

        let t = state.1 << 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3

        state.2 ^= t

        state.3 = rotl(state.3, 45)

        return result
    }
}
