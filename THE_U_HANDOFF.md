# Project handoff: The U

I am building a browser-first 3D college-life sports RPG called **The U**.

This document summarizes the product vision, previous work, lessons learned, and expectations for the new implementation.

## Creator context

I am a solo developer with a computer science and product background.

I am comfortable with:

* React
* TypeScript
* Next.js
* web applications
* product design
* mobile interfaces
* AI-assisted development

I want an LLM-first development workflow where the project can be built, tested, rendered, deployed, and iterated primarily through code and terminal tools.

The project should be commercially viable, visually compelling, and capable of expanding beyond an initial browser release.

## Core concept

The U is a college-life sports RPG.

The player arrives at a fictional American university as a new student. They explore campus, form relationships, attend classes, manage their schedule, train athletically, build a reputation, and pursue an opportunity to become a college athlete.

The game is not only about playing sports.

The core fantasy is:

> Arriving at college and deciding who you are going to become.

The player must balance:

* athletics
* academics
* friendships
* rivalries
* social life
* romance
* money
* health
* energy
* reputation
* personal ambition

Choices should have consequences that persist across the game.

## Setting

The fictional university is currently called:

**North Valley State University**

The athletic teams are:

**The Ridgehawks**

Current branding direction:

* navy primary color
* gold accent color
* modern fictional university identity
* American college campus atmosphere

These names can be improved when a stronger creative direction is found, but do not use real university trademarks, logos, mascots, uniforms, or building designs.

## Important characters

### Jordan Hayes

Jordan is one of the first people the player meets.

Jordan should be visually distinctive and memorable. Depending on player choices, Jordan may become:

* a close friend
* a roommate
* a teammate
* a rival
* a social connection
* a source of opportunities

Previous introductory dialogue:

> "First day too? I'm trying to figure out whether this place is a campus or a whole city."

Jordan must feel like a real character with personal goals and an independent life, not an NPC waiting to deliver exposition.

### The coach

The coach evaluates the player based on:

* skill
* work ethic
* attitude
* athletic performance
* academics
* reputation
* teammate relationships
* behavior under pressure

### Roommate

The roommate grounds the player in everyday campus life and should have an independent schedule, personality, relationships, conflicts, and goals.

### Rival

The rival may be athletic, academic, or social.

The rival should not simply be evil. Their motivations should be understandable and their relationship with the player should change dynamically.

## Original milestone plan

The initial development roadmap was:

1. Movement and world presence
2. Dialogue and consequences
3. Scene and location transitions
4. Time and activities
5. One complete playable day
6. Athletic tryout
7. Save, continue, and reset
8. Character creation
9. First playable week
10. Content and polish

The first complete vertical slice was intended to include:

* campus courtyard
* visible player
* camera follow
* keyboard and touch movement
* collision
* Jordan
* interaction prompt
* dialogue
* stat effects
* scene transitions
* a playable first day

The eventual MVP should cover the player's first week at North Valley State.

## Previous Godot implementation

The first version was built using:

* Godot 4
* GDScript
* stylized 3D assets
* mobile landscape controls
* browser export

The functional prototype successfully demonstrated:

* 3D movement
* camera follow
* player animation
* touch joystick
* collision
* proximity detection
* Jordan interaction
* dialogue opening and closing
* mobile web execution

The project repository was:

`micahp/college-sports-rpg`

The deployed browser build was previously hosted through GitHub Pages and temporary Cloudflare tunnels.

## Why the Godot version was rejected

The project worked technically, but it did not meet the visual standard.

The first demo looked like:

* a generic asset-pack demonstration
* a park rather than a university
* programmer art
* anonymous low-poly characters
* a technical prototype rather than a desirable game

Specific problems included:

* overly bright green grass
* washed-out pavement
* harsh shadows
* distant camera framing
* too much empty ground
* generic Quaternius-style characters
* weak character silhouettes
* stiff animation
* almost no facial expression
* no compelling campus fashion
* generic touch controls
* generic dialogue interface
* weak university identity
* little environmental storytelling
* no meaningful sense of athletic aspiration

The player did not look like someone users would want to become.

Jordan looked like a variation of the same generic model.

## Fable visual redesign attempt

Fable was given a large visual-redesign prompt and spent nearly all available usage credits attempting to improve the Godot build.

It:

* downloaded additional CC0 asset packs
* imported FBX, GLB, and glTF assets
* added more character variants
* added six background students
* created North Valley State branding
* procedurally generated a Ridgehawk emblem
* generated campus banners and signs
* added a Recreation Center facade
* added audio
* improved the HUD
* added a dialogue portrait
* implemented camera transitions
* improved responsive anchoring
* generated editor-readable Godot scene files
* moved runtime world generation into development-time scene generation
* reduced the main runtime campus script
* added screenshot and gameplay tests

The engineering and architecture improved considerably.

However, the finished visual slice was still rejected.

## Why the redesigned version still failed

The redesign produced a technically stronger version of the same aesthetic.

It added more:

* props
* NPCs
* signs
* branding
* sound
* scripts
* environmental detail

But it did not produce a compelling visual identity.

The updated build still had:

* generic low-poly characters
* weak facial readability
* stiff body language
* asset-pack visual language
* a distant management-game-like camera
* cluttered rather than art-directed composition
* lighting that remained too bright
* awkward conversation staging
* characters standing too close together
* overlapping bodies during dialogue
* controls that still looked temporary
* a world that did not feel aspirational

The key test was:

> Would I proudly post this footage without calling it an early prototype?

The answer was no.

The decision was made to stop spending Fable credits and start a clean implementation using Kimi K3 and a browser-native 3D stack.

## Lessons from the previous project

### 1. Technical functionality is not enough

Movement, collision, dialogue, and touch controls can all work while the game still fails emotionally and visually.

### 2. The visual direction must be approved early

Do not spend weeks building systems around an art direction that has not proven compelling.

### 3. More assets do not automatically produce better art direction

Adding trees, benches, students, signs, and banners can create clutter rather than quality.

Every visual element must support:

* composition
* atmosphere
* storytelling
* player fantasy
* navigation

### 4. Character quality matters more than prop count

The player and major NPCs are the product.

They must be:

* aspirational
* attractive
* expressive
* fashionable
* emotionally readable
* visually distinctive

Do not use weak placeholder characters and assume they can be fixed later.

### 5. Do not use the previous generic character pack

Avoid the Quaternius-style models used in the Godot version.

Do not use characters that resemble:

* mannequins
* stick figures
* generic low-poly pedestrians
* anonymous mobile-game NPCs
* obvious asset-pack defaults

### 6. The camera should be character-focused

The previous camera was too high and distant.

The new version should feel closer to:

* a character-driven RPG
* a stylish life simulator
* a cinematic social game

It should not resemble:

* a city builder
* a management game
* an isometric strategy title

### 7. Use web-native UI strengths

One reason for moving to React and Three.js is the ability to create premium interfaces using normal HTML and CSS.

The UI should not look like engine-default controls layered over a canvas.

### 8. Do not preserve work because of sunk cost

The Fable version consumed almost all of roughly $100 in credits.

That does not justify continuing with a weak result.

The new project should prioritize the final experience rather than preserving previous implementation decisions.

## New technical direction

Start from a clean repository.

Preferred stack:

* Vite
* React
* TypeScript
* Three.js
* React Three Fiber
* Drei
* React Three Rapier
* Zustand
* HTML and CSS interface overlays

You may choose stronger alternatives when justified.

The architecture should support:

* mobile and desktop browsers
* touch controls
* keyboard and mouse
* reusable character systems
* animation
* physics
* dialogue
* schedules
* relationships
* saving
* additional sports
* additional campuses
* expanding story content
* automated screenshots
* gameplay testing
* rapid AI-assisted iteration

## Desired visual direction

The game should be:

* modern
* youthful
* aspirational
* social
* fashionable
* athletic
* cinematic
* stylized
* expressive
* grounded in recognizable American college life

It should be suitable for:

* announcement screenshots
* short social clips
* a landing page
* a publisher pitch
* crowdfunding
* an app-store listing
* a Steam page

A viewer should immediately understand:

> This is a college-life game about becoming a student athlete.

## Campus expectations

The campus should feel active and lived in.

Important locations eventually include:

* dorm
* Recreation Center
* gym
* training facility
* academic buildings
* classrooms
* library
* dining hall
* student union
* campus store
* outdoor plaza
* athletic offices
* practice courts
* social venues
* nearby off-campus area

The world should include:

* students walking between classes
* groups talking
* club tables
* posters
* bikes and scooters
* athletes training
* performances
* protests
* events
* campus traditions
* changing time and weather
* environmental storytelling

NPCs should appear to have lives beyond waiting for the player.

## First-week gameplay target

The first complete experience should allow the player to:

1. Create a character.
2. Arrive at North Valley State.
3. Move into the dorm.
4. Meet their roommate.
5. Explore campus.
6. Meet Jordan.
7. Attend orientation.
8. Discover a basketball opportunity.
9. Meet the coach.
10. Attend classes.
11. Study or neglect academics.
12. Train.
13. Attend social events.
14. Build relationships.
15. Make meaningful choices.
16. Complete a basketball tryout.
17. Receive an outcome based on the entire week.
18. Reach a satisfying Week 1 conclusion.
19. Replay with different decisions.

Possible outcomes include:

* making the team
* receiving a walk-on opportunity
* joining a development path
* failing the tryout
* losing eligibility
* discovering another opportunity
* creating a rivalry
* building an important friendship
* unlocking a different personal path

The result should depend on more than athletic skill.

It should incorporate:

* academics
* relationships
* reputation
* fatigue
* confidence
* work ethic
* decisions
* tryout performance

## Basketball

Basketball is the first complete sport.

It should eventually include:

* shooting
* conditioning
* ball handling
* defense
* scrimmages
* practices
* tryouts
* competitive games
* coach evaluation
* teammate chemistry
* clutch moments

The architecture should allow more sports to be added later.

## Time and choice

The player should not be able to do everything.

Activities consume:

* time
* energy
* money
* social opportunities
* academic opportunities
* athletic opportunities

The player must choose between:

* training
* class
* studying
* social events
* rest
* work
* exploration
* relationships
* special opportunities

The schedule should create pressure without becoming tedious.

## Relationships

Relationships should not be simple visible numbers.

Characters should remember:

* promises
* insults
* support
* betrayal
* favors
* missed events
* shared experiences
* competition
* romantic interest
* loyalty
* important choices

Relationships should open and close story paths.

## Dialogue

Dialogue should be:

* concise
* natural
* character-specific
* reactive
* consequential

Avoid:

* generic exposition
* long text dumps
* every character sounding the same
* fake choices
* choices with identical outcomes
* repetitive greetings
* constant stat explanations

## Character creation

The player should eventually control:

* name
* appearance
* hairstyle
* skin tone
* clothes
* pronouns
* background
* personality traits
* athletic strengths
* academic strengths
* motivation

These decisions should change gameplay, dialogue, opportunities, and initial relationships.

## Interface

The interface should feel like a premium game product.

Potential systems include:

* HUD
* dialogue
* schedule
* campus map
* player profile
* relationships
* academics
* athletics
* inventory
* clothing
* opportunities
* quests
* messages
* social feed
* settings
* saving and loading

The player's phone may serve as the central interface for:

* schedule
* messages
* map
* team updates
* relationships
* academic alerts
* opportunities
* social information

## Quality expectation

Do not treat "prototype" as permission to make weak work.

Do not stop when the game technically runs.

Continue until the result feels:

* cohesive
* polished
* intentional
* enjoyable
* distinctive
* emotionally engaging
* performant
* replayable
* publicly presentable

Replace weak work instead of defending it.

Do not preserve an implementation only because effort was spent on it.

The result matters more than sunk cost.

## Asset and license requirements

Use only:

* original assets
* CC0 assets
* commercially safe assets
* assets with clearly documented licenses

Maintain an asset-license file containing:

* asset name
* creator
* source
* license
* modifications
* usage location

Do not use real university intellectual property.

## Working style

Take ownership of creative and technical decisions.

Do not ask for approval after every minor step.

Research and obtain the necessary assets and tools.

Test continuously.

Use screenshots and gameplay recordings to evaluate quality.

Do not claim planned improvements are complete.

Implement and verify them.

When something looks weak, replace it.

## Final goal

Build a game that makes players feel:

* excitement about arriving on campus
* curiosity about the people around them
* pressure from limited time
* pride in athletic improvement
* emotional investment in relationships
* consequences from their choices
* anticipation for what happens next

A person should watch a short clip and immediately think:

> I want to play this.
