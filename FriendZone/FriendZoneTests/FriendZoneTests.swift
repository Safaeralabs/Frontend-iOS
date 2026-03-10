//
//  FriendZoneTests.swift
//  FriendZoneTests
//
//  Created by Safaera Labs on 05.03.26.
//

import Testing
@testable import FriendZone

struct FriendZoneTests {

    @Test func authenticatedUserDecodesPkFallback() throws {
        let data = Data(
            """
            {
              "pk": 42,
              "username": "safa",
              "email": "safa@example.com",
              "first_name": "Safa",
              "last_name": "Era",
              "has_profile": true,
              "is_event_creator": true,
              "is_venue_owner": false,
              "onboarding_completed": true
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let user = try decoder.decode(AuthenticatedUser.self, from: data)

        #expect(user.id == 42)
        #expect(user.username == "safa")
        #expect(user.firstName == "Safa")
        #expect(user.isEventCreator == true)
        #expect(user.onboardingCompleted == true)
    }

    @Test func hangoutFeedDecodesBackendShape() throws {
        let data = Data(
            """
            {
              "id": 9,
              "host": 7,
              "host_username": "hoster",
              "title": "Afterwork Drinks",
              "description": "Quick meetup",
              "cover_image_url": null,
              "city_name": "Berlin",
              "location_name": "Canal Bar",
              "start_at": "2026-03-10T18:00:00Z",
              "end_at": "2026-03-10T20:00:00Z",
              "capacity": 6,
              "approved_participants_count": 3,
              "status": "active",
              "source_type": "event",
              "source_event_id": 401,
              "source_offer_id": null,
              "vibe": "drinks",
              "is_micro": false,
              "is_live": true,
              "participants": [
                {
                  "id": 1,
                  "hangout": 9,
                  "user": 7,
                  "username": "hoster",
                  "status": "approved",
                  "joined_at": "2026-03-10T17:00:00Z"
                },
                {
                  "id": 2,
                  "hangout": 9,
                  "user": 12,
                  "username": "maya",
                  "status": "approved",
                  "joined_at": "2026-03-10T17:10:00Z"
                }
              ],
              "join_requests": [
                {
                  "id": 77,
                  "hangout": 9,
                  "user": 99,
                  "user_username": "luca",
                  "message": "Can I join?",
                  "status": "pending",
                  "invite_code_used": "",
                  "created_at": "2026-03-10T17:20:00Z"
                }
              ]
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let hangout = try decoder.decode(HangoutFeedItem.self, from: data)

        #expect(hangout.id == 9)
        #expect(hangout.hostUsername == "hoster")
        #expect(hangout.cityName == "Berlin")
        #expect(hangout.sourceType == "event")
        #expect(hangout.participants.count == 2)
        #expect(hangout.joinRequests.first?.userUsername == "luca")
    }

    @Test func appConfigBuildsLocalAPIURL() {
        let url = AppConfig.url(for: "/api/auth/user/")
        #expect(url.absoluteString.contains("/api/auth/user/"))
    }

}
