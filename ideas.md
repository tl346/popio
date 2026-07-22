cuztomizable aesthetic (emojis in names)

events you may like/nearby

Target: older women, college kids, postgrad

free promotion for popups/reservation list

More interactive (free drink promos)

MVPs:
points when people like an event you posted
points when people like reviews you posted
points when people like photos you have posted
points when people like tips you have posted

Things To Do:
- Vendor spot marketplace
- UI/UX cleanup
- Design Logo
- Design Splashscreen
- User/Moderator System
- Redesign bottom menu bar
- New Color schema
- Redesign login/register page
- Additional points for more information added to an event

Do the following for me:
- Change all referenes of MVPs to Leaderboard
- Remove the badges system where a specific badge is given for being ranked X based on points
- In the Leaderboards, move each users points so that it is right aligned and their @ is left aligned
- Get rid of the rounded border encompassing each user in the leaderboard, and make the list more compact and clean.
- Get rid of the titles in all pages
- Remove both the heart button and the category badge from the image of an event
- Add a "distance to" value (such as 0.7 mi) on the right of the date in the Pop-up view
- Get rid of "Tips" section and all its functionality


When loading the app, place me onl the login screen. Also I want to change the login/register page format so that on the login page, there is a section on the bottom with "Already have an account? Sign In" on the Register page and "New Here? Create an account" on the Login Page

For the Profile Page

Make the following changes:
- When I tap outside of the search bar, i want it to hide the location search bar.
- 

Set the following character limits when a user is registering for each field:
- First name: 30
- Last name: 30
- Email: 254
- Display Name: 30
- Password: 128

Using popuplistview.png as inspiration, redesign my pop-up list view with the following in mind:
- don't mind the featured label
- No need to add the profile, alert, and logo on the top
- Change the Nearest dropdown to a radius dropdown so that text dynamically changes based on the setting. For example 30 pop-ups within 10 miles, and 15 pop-ups within 5 miles. The settings should be 5 miles, 10 miles, 25 miles, and 50 miles


On the map view, I want to get rid of the text that says "x pop-ups shown on map" from below the search bar and also under the "Pop-ups near you" title

Make the following changes:
- Make all backgrounds white
- Remove the purple tint from the bottom menu bar

Redesign the pop-up list view using squarelistview.png as inspiration and taking the following into account:
- Below the title of the event should be the category badge
- The calendar button should be replaced with a bookmark button without a border. (bookmarking equates to a like)
- I only want the event layout to be editted. dont touch the bottom menu bar and anything above filters including filters

Change the "Add Event" page as follows:
- Move the Event Name field below the add photo field. (sized identically to location field)
- Make the add photo field centered,larger, and a square (with non-rounded corners)

Redesign the Event Page using squareevent.png as inspiration with the following changes:
- Where the "Floral Pop-up" is, it should be replaced with category badges
- Don't add the symbol on the left of the About section
- Make sure the photo is large, square, and non-rounded edges
- Replace Category with Tags
- Make Hosted by, Found by instead
- add functionality to the follow button which sends a friend request to that users.
- Change the "Add to calendar" button to "Going"
- Change the "View on Map" button to "Chatroom" 
- Always lock the Going and Chatroom buttons to the bottom of the screen. (outside of scrollable area)
- Keep the going stacked profile pics below the Found by section
- Keep the add photo section below the stacked profile pics that are going section
- Change the photo grid to be non-rounded corner squares

make the following changes:
- make the square image inside the event page slightly smaller
- make the heart button, share button, and back button inside the event page smaller
- Make the Going and chatroom buttons slightly thinner vertically and position them closer to the bottom menu bar.
- the buttons in the bottom menu bar are too high, position the lower and then reduce the vertical space of the bottom menu bar area as well accordingly

When using a filter, I want the pill the to be filled with the corresponding pastel color and the text to turn white

Crop, resize, do whatever needed to achieve the following.
- Make the logo title image on the splashscreen identical in size to the one on the login screen.
- There is too much deadspace between the logo title image on the login screen and the email/username input field

Make the following changes:
- Ensure the "This Week" filter accurately tracks users who gained the most points this week (also make sure All Time works for total points in users history)
- Make the "1" icon on the leaderboards page pastel yellow

Everything in the login page currently feels shifted upwards a bit much. I want it centered (vertically)

Move everything below the "This Week/All Time" filter on the leaderboards page a very slightly lower

I don't want an account deletion to result in the following:
      - Events created by the user (just indicate user is deactivated)
      - Contributions/chat/photo records created by the user (dont delete these)
      - User likes from other events/contributions (keep the likes)
      - Profile image and user-created event/contribution images from Firebase
        Storage when possible

Make the following changes ONLY for users who are admins:
- Replace the Add Icon in the bottom menu bar with review icon
- the review icon should open a page that shows pending events that the admin can open, review, and Approve or Reject with a button on the very bottom.
- The review page should be identical to the pop-up list view, and the approve and reject buttons should be inside the event page (which should also look identical to the event page view for standard users)

Mitigate the following issue for me (I believe we already resolved the issue of auto-approved submissions fyi):
**High: UGC moderation is not App Store-ready.**
Your app has user-generated events, photos, and chat messages, but submissions are currently auto-approved in [AppSession.swift](/Users/tonyleee/src/Pophub/Popio/Core/Services/AppSession.swift:638) and [AppSession.swift](/Users/tonyleee/src/Pophub/Popio/Core/Services/AppSession.swift:700). Apple requires apps with UGC to include filtering, reporting, blocking abusive users, and published contact info. Your app has admin approve/reject plumbing, but I did not find user-facing report/block flows. This is the biggest rejection risk. Apple guideline 1.2 explicitly calls this out. Source: Apple App Review Guidelines, UGC requirements lines 222-230. https://developer.apple.com/app-store/review/guidelines/
- Style the report button in-line with how the like button is done. (placed next to like button)

Give users the ability to tap a photo in the event page and have it expand so they can have a better view of the photo. Let photos have a like button on the top right in the expanded view, so users can like it and a "PC: @user1" (picture credit for user who uploaded the photo) on the top left. Likes on a photo should give 5 points to the user who uploaded the photo