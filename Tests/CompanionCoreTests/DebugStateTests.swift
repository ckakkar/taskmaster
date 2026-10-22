#if DEBUG
    import Testing

    @testable import CompanionCore

    @Test func debugWorkloadsHoldTheirStateForLongerThanAMeasurementWindow() {
        for avatar in AvatarKind.available {
            for selected in DebugPetState.allCases {
                var pet = PetEngine(habitat: Habitat(left: 110, right: 1330, floor: 20, ceiling: 800), seed: 1)
                pet.avatar = avatar
                let accepted = pet.startDebugState(selected)
                if avatar == .miso && selected == .flying {
                    #expect(!accepted && pet.debugState == nil)
                    continue
                }
                #expect(accepted)
                let initial = pet.position
                var travelled = 0.0
                for _ in 0..<4800 {
                    let previous = pet.position
                    pet.tick(seconds: 1.0 / 60, userIdle: 9999)
                    travelled += previous.distance(to: pet.position)
                    #expect(pet.state.rawValue == selected.rawValue)
                    #expect(pet.habitat.clamped(pet.position) == pet.position)
                }
                if selected == .sitting || selected == .sleeping {
                    #expect(pet.position == initial && travelled == 0)
                } else {
                    #expect(travelled > 2000)
                }
            }
        }
    }
#endif
