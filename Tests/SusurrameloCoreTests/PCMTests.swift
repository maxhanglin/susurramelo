import Testing
@testable import SusurrameloCore

@Suite struct PCMTests {
    @Test func convertsFloatSamplesToInt16LittleEndian() {
        let data = PCM.int16LittleEndianData(from: [0, 1, -1, 0.5])
        #expect(Array(data) == [
            0x00, 0x00, // 0
            0xFF, 0x7F, // 32767
            0x01, 0x80, // -32767
            0xFF, 0x3F, // 16383
        ])
    }

    @Test func clampsOutOfRangeSamples() {
        let data = PCM.int16LittleEndianData(from: [2.0, -3.0])
        #expect(Array(data) == [0xFF, 0x7F, 0x01, 0x80])
    }

    @Test func emptyInputProducesEmptyData() {
        #expect(PCM.int16LittleEndianData(from: []).isEmpty)
    }
}
