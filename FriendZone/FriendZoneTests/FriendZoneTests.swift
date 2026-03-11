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
              "lat": 52.5208,
              "lng": 13.4095,
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
        #expect(hangout.lat == 52.5208)
        #expect(hangout.lng == 13.4095)
        #expect(hangout.sourceType == "event")
        #expect(hangout.participants.count == 2)
        #expect(hangout.joinRequests.first?.userUsername == "luca")
    }

    @Test func discoveryEventFeedDecodesOptionalCoordinates() throws {
        let data = Data(
            """
            {
              "id": 401,
              "title": "Midnight Neo-Soul Jam",
              "venue_name": "Neon Hall",
              "city": "Berlin",
              "city_place_id": "berlin-place",
              "lat": 52.5176,
              "lng": 13.4049,
              "start_at": "2026-03-15T20:00:00Z",
              "end_at": "2026-03-15T23:00:00Z",
              "category": "Music",
              "primary_image_url": null,
              "creator": 7,
              "creator_username": "neon",
              "creator_display_name": "Neon Events",
              "creator_avatar_url": null,
              "spots_remaining": 18,
              "hangouts_count": 4
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let event = try decoder.decode(DiscoveryEventFeedItem.self, from: data)

        #expect(event.id == 401)
        #expect(event.lat == 52.5176)
        #expect(event.lng == 13.4049)
        #expect(event.city == "Berlin")
    }

    @Test func notificationFeedDecodesBackendShape() throws {
        let data = Data(
            """
            {
              "id": 11,
              "type": "join_approved",
              "type_display": "Join Request Approved",
              "title": "Join approved",
              "message": "You were accepted in Sunset Rooftop Drinks",
              "action_url": "/hangouts/77",
              "related_hangout_id": 77,
              "related_event_id": null,
              "related_user_id": 5,
              "read": false,
              "read_at": null,
              "created_at": "2026-03-11T09:00:00Z",
              "time_ago": "hace 2 minutos"
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let notification = try decoder.decode(AppNotificationFeedItem.self, from: data)

        #expect(notification.id == 11)
        #expect(notification.type == "join_approved")
        #expect(notification.relatedHangoutId == 77)
        #expect(notification.read == false)
        #expect(notification.timeAgo == "hace 2 minutos")
    }

    @Test func eventSoloJoinFeedDecodesBackendShape() throws {
        let data = Data(
            """
            {
              "id": 901,
              "event_id": 401,
              "event_title": "Midnight Neo-Soul Jam",
              "venue_name": "Neon Hall",
              "creator_name": "Neon Events",
              "start_at": "2026-03-15T20:00:00Z",
              "end_at": "2026-03-15T23:00:00Z",
              "joined_at": "2026-03-11T10:00:00Z"
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let item = try decoder.decode(EventSoloJoinFeedItem.self, from: data)

        #expect(item.id == 901)
        #expect(item.eventId == 401)
        #expect(item.eventTitle == "Midnight Neo-Soul Jam")
        #expect(item.creatorName == "Neon Events")
    }

    @Test func creatorVenueFeedDecodesBackendShape() throws {
        let data = Data(
            """
            {
              "id": 7001,
              "name": "Mitte Bean Lab",
              "category": "cafe",
              "status": "active",
              "city": "Berlin",
              "address": "Rosenthaler Str. 21",
              "total_hangouts": 22,
              "total_offers": 5,
              "total_people_reached": 318,
              "is_verified": true
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let venue = try decoder.decode(CreatorVenueFeedItem.self, from: data)

        #expect(venue.id == 7001)
        #expect(venue.name == "Mitte Bean Lab")
        #expect(venue.status == "active")
        #expect(venue.totalOffers == 5)
        #expect(venue.isVerified == true)
    }

    @Test func appConfigBuildsLocalAPIURL() {
        let url = AppConfig.url(for: "/api/auth/user/")
        #expect(url.absoluteString.contains("/api/auth/user/"))
    }

}
