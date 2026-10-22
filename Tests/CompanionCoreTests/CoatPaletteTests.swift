import Testing

@testable import CompanionCore

@Test func coatTonesHaveDistinctVisibleColorsAndKeepCreamAndTransparency() {
    let original: [UInt8] = [220, 90, 30, 255, 250, 239, 220, 255, 50, 25, 10, 128, 0, 0, 0, 0]
    var rendered: [[UInt8]] = []
    for style in CoatStyle.allCases {
        var pixels = original
        CoatPalette.recolor(&pixels, style: style)
        rendered.append(Array(pixels.prefix(3)))
        #expect(Array(pixels[4..<8]) == Array(original[4..<8]))
        #expect(pixels[11] == 128 && Array(pixels[12..<16]) == [0, 0, 0, 0])
    }
    #expect(Set(rendered).count == 4)
    #expect(rendered[2][2] > rendered[2][1])
    #expect(abs(Int(rendered[3][0]) - Int(rendered[3][2])) < 45)
}
