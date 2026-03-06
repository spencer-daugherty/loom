import SwiftUI
import SwiftData
import UIKit

fileprivate struct FulfillmentStartCategoryDef: Identifiable {
    let id: String
    let title: String
    let categoryID: UUID
}

fileprivate let fulfillmentStartDefaultCategoryDefs: [FulfillmentStartCategoryDef] = [
    .init(id: "career", title: "Career & Business", categoryID: PlanLabelSeeder.categoryIDs["Career & Business"]!),
    .init(id: "leadership", title: "Leadership & Impact", categoryID: PlanLabelSeeder.categoryIDs["Leadership & Impact"]!),
    .init(id: "wealth", title: "Wealth & Lifestyle", categoryID: PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!),
    .init(id: "mind", title: "Mind & Meaning", categoryID: PlanLabelSeeder.categoryIDs["Mind & Meaning"]!),
    .init(id: "love", title: "Love & Relationships", categoryID: PlanLabelSeeder.categoryIDs["Love & Relationships"]!),
    .init(id: "health", title: "Health & Vitality", categoryID: PlanLabelSeeder.categoryIDs["Health & Vitality"]!),
]

let fulfillmentStartSelectableDefaultCategories: [String] = [
    "Career & Business",
    "Faith & Spirituality",
    "Wealth & Finance",
    "Learning & Education",
    "Love & Relationships",
    "Health & Energy",
    "Lifestyle & Experiences",
    "Mindset & Resilience",
    "Service & Impact",
    "Home & Life"
]

fileprivate let fulfillmentStartMissionSuggestionCorpusByCategory: [String: String] = [
    "Career & Business": """
I build work that uses my abilities well and creates real value for others. Progress here strengthens my independence and confidence. When this area grows, I gain momentum and opportunity across my life.
My work allows me to apply my strengths to meaningful challenges. Improving here gives me stability and direction instead of uncertainty. When this area is strong, I feel capable and purposeful in how I spend my time.
I contribute value through the work I choose to pursue. Strengthening this area expands my opportunities and my ability to shape my future. When this area grows, I move through life with greater control and confidence.
My career allows me to build skills that compound over time. Improving here strengthens my ability to support myself and those I care about. When this area is strong, progress in other parts of life becomes easier.
I use my work to create meaningful impact and long-term progress. Strengthening this area builds stability, freedom, and opportunity. When this area grows, I gain the ability to shape my life more intentionally.
My work reflects my abilities and the value I bring to the world. Improving here strengthens my confidence and sense of direction. When this area is strong, I feel energized instead of drained by how I spend my time.
I develop skills that allow me to solve meaningful problems. Strengthening this area expands both my impact and my opportunities. When this area grows, I create momentum that benefits every part of my life.
My career gives structure to how I grow and contribute. Improving here increases my independence and long-term stability. When this area is strong, I can focus on building a life that feels intentional and rewarding.
I build work that challenges me to improve while creating value for others. Strengthening this area increases my confidence and resilience. When this area grows, I move forward with greater clarity and momentum.
My work allows me to grow, contribute, and create lasting value. Improving here builds both stability and opportunity for the future. When this area is strong, I feel capable of handling whatever challenges arise.
I use my career to develop skills that compound over time. Strengthening this area expands my ability to contribute and create opportunities. When this area grows, I gain both confidence and freedom in my life.
My work allows me to apply my talents toward meaningful outcomes. Improving here strengthens my sense of progress and self-reliance. When this area is strong, I move through life with greater confidence and clarity.
I pursue work that challenges me and allows me to grow. Strengthening this area increases my resilience and ability to solve problems. When this area grows, I create stability and opportunity for the future.
My career is a place where effort turns into progress and value. Improving here builds both competence and independence. When this area is strong, I feel confident shaping my direction in life.
I develop skills and experiences that expand what I am capable of achieving. Strengthening this area increases both my impact and my stability. When this area grows, the rest of life becomes easier to navigate.
I build a career that reflects both my strengths and my values. Strengthening this area increases my freedom to choose how I spend my time and energy. When this area grows, I feel aligned with the life I am building.
My work helps me create stability, progress, and opportunity over time. Improving here increases my confidence in my ability to navigate challenges. When this area is strong, I move through life with greater clarity and momentum.
I develop work that allows my abilities to create meaningful results. Strengthening this area expands my opportunities and my influence. When this area grows, I gain the freedom to build the life I want.
My career is where effort becomes progress and ideas become real outcomes. Improving here strengthens my independence and long-term stability. When this area is strong, I feel confident building a future I believe in.
My work allows me to contribute meaningfully while continuing to grow. Improving here strengthens my sense of capability and purpose. When this area is strong, I gain momentum that carries into every other part of life.
""",
    "Faith & Spirituality": """
My faith keeps my life anchored in something greater than myself. It reminds me that my actions, struggles, and growth all have meaning beyond the moment. Strengthening this area keeps me grounded, humble, and directed toward what truly matters.
My spiritual life helps me live with purpose instead of drifting through daily pressures. It reminds me that my character and choices matter more than temporary outcomes. When this area is strong, I feel centered and guided.
Faith gives me perspective when life feels uncertain or overwhelming. It reminds me that I am not carrying everything alone and that challenges can shape me. Strengthening this area brings calm, clarity, and resilience.
My spiritual life helps align my values, decisions, and actions. It keeps me honest about who I want to be and how I treat others. When this area grows stronger, my life feels more consistent and meaningful.
Faith keeps my priorities in the right order. It reminds me that success without meaning is empty and that character matters more than status. Strengthening this area keeps my life balanced and purposeful.
My spirituality reminds me to live with gratitude instead of entitlement. It helps me notice the good in life and appreciate the people around me. When this area grows stronger, I feel more peace and contentment.
Faith strengthens my ability to face hardship with courage. It reminds me that growth often comes through difficulty and that perseverance matters. When this area is strong, I respond to challenges with steadiness.
My spiritual life reminds me that my life is meant to serve something beyond myself. It encourages me to care for others and contribute positively to the world. Strengthening this area gives my life deeper meaning.
Faith helps me pause and reflect instead of reacting impulsively. It encourages patience, humility, and thoughtful choices. When this area grows stronger, I respond to life with greater wisdom.
My spiritual foundation keeps me grounded when life becomes busy or chaotic. It creates space for reflection and connection with what truly matters. Strengthening this area brings clarity and stability.
Faith reminds me that my identity is deeper than achievements or failures. It helps me see my worth beyond external success. When this area is strong, I feel more secure and centered.
My spirituality encourages me to live with integrity and compassion. It shapes how I treat others and how I respond to challenges. Strengthening this area helps me become the person I want to be.
Faith helps me stay hopeful even when circumstances are uncertain. It reminds me that setbacks do not define my future. When this area grows stronger, I carry a deeper sense of trust and optimism.
My spiritual life keeps me connected to reflection and stillness. It gives me space to slow down and listen instead of constantly reacting. Strengthening this area helps me live with greater awareness.
Faith reminds me that life is about more than personal gain. It encourages generosity, humility, and service to others. When this area is strong, my actions feel more meaningful.
My spirituality helps me see life through a lens of purpose rather than pressure. It reminds me that growth, learning, and compassion are part of a larger journey. Strengthening this area deepens my sense of direction.
Faith helps me find peace in moments that feel uncertain or difficult. It reminds me that I can trust the process of growth and change. When this area grows stronger, I feel calmer and more grounded.
My spiritual life encourages reflection on who I am becoming. It helps me step back from distractions and focus on what truly matters. Strengthening this area brings clarity to my values and direction.
Faith keeps me connected to gratitude, humility, and perspective. It reminds me that every day offers opportunities to grow and serve. When this area is strong, I experience deeper fulfillment.
My spirituality reminds me to live intentionally instead of drifting through life. It keeps my actions aligned with deeper meaning and purpose. Strengthening this area brings peace, direction, and fulfillment.
""",
    "Wealth & Finance": """
I build financial stability so daily decisions are not controlled by stress or scarcity. When my finances are strong, I have the freedom to focus on what matters most.
I strengthen my finances so I can live with greater independence and peace of mind. Financial strength allows me to make choices based on values instead of pressure.
I develop financial discipline so my future becomes more secure and flexible. Each improvement creates more freedom in how I live and work.
I grow my financial resources so I can create opportunities instead of reacting to limitations. Stability here strengthens every other area of life.
I manage money wisely so my life becomes more stable and less reactive. Strong finances allow me to move forward with confidence.
I strengthen my financial foundation so unexpected problems do not control my life. Stability here gives me calm and long-term security.
I build financial resilience so challenges do not derail my progress. When this area is strong, I can focus on growth instead of survival.
I improve my financial habits so my life becomes more stable and intentional. Progress here removes pressure and expands my options.
I grow financial discipline so my future becomes more predictable and secure. Strength in this area creates freedom and momentum.
I strengthen my finances so I can support the life I truly want to build. When money is managed well, everything else becomes easier.
I build financial clarity so decisions about money become simple and confident. Strong finances allow me to focus on long-term progress.
I develop consistent financial habits so my resources steadily grow over time. Stability here creates lasting peace of mind.
I strengthen my financial position so I can handle uncertainty without fear. Progress in this area makes life more stable and flexible.
I improve how I manage money so my life becomes more organized and secure. Financial stability supports everything I want to achieve.
I grow my financial capacity so I can create opportunities for myself and others. When this area improves, my impact expands.
I strengthen financial discipline so my future is built on stability rather than chance. Progress here supports every other priority.
I manage my finances intentionally so my life becomes more secure and less stressful. Strong financial systems create freedom.
I build financial strength so I can pursue meaningful goals without constant pressure. Stability here unlocks long-term progress.
I develop financial wisdom so my resources grow and support the life I am building. Progress here brings confidence and clarity.
I strengthen my finances so I can live with greater freedom, stability, and generosity. When this area improves, everything else becomes easier.
""",
    "Learning & Education": """
I continuously grow my understanding of the world and how it works. Learning expands my perspective and helps me make better decisions. A curious mind keeps my life evolving instead of standing still.
I actively develop knowledge and skills that make me more capable. Each thing I learn strengthens my confidence and independence. Growth keeps my mind sharp and adaptable.
I challenge myself to keep learning and improving. Expanding my knowledge helps me navigate complexity with clarity. Progress in learning creates momentum across every part of my life.
I stay curious and open to new ideas. Learning helps me see opportunities others might miss. A growing mind allows me to keep evolving throughout life.
I invest time into understanding new concepts and perspectives. Knowledge gives me tools to think clearly and act wisely. The more I learn, the more capable I become.
I strengthen my mind through continuous learning. Each new insight helps me understand people, systems, and the world more deeply. Intellectual growth keeps life interesting and meaningful.
I build knowledge that helps me think critically and independently. Learning gives me confidence in my decisions and direction. A strong foundation of understanding supports everything else I pursue.
I commit to developing new skills and expanding my thinking. Learning allows me to solve problems and adapt when challenges arise. Growth in knowledge unlocks new possibilities.
I remain curious about the world and eager to understand it. Learning broadens my perspective and improves my judgment. When my mind grows, my life grows with it.
I actively seek knowledge that sharpens my thinking. Understanding how things work helps me move through life with clarity and purpose. Learning keeps my mind engaged and alive.
I strengthen my ability to think, question, and understand. Learning helps me make wiser choices and avoid repeating mistakes. A growing mind makes the future more open.
I continuously explore ideas, skills, and perspectives. Learning expands my awareness and improves how I approach challenges. Knowledge becomes a tool I carry through life.
I build a habit of curiosity and discovery. Learning helps me see patterns, connections, and possibilities. A curious mind keeps life engaging and meaningful.
I develop knowledge that empowers me to think clearly and act wisely. Learning strengthens my confidence and independence. Each insight adds to my ability to navigate life well.
I commit to understanding more about the world and my place in it. Learning deepens my awareness and sharpens my thinking. Growth in knowledge keeps my life moving forward.
I strengthen my ability to learn, adapt, and improve. Each new skill or idea expands what I am capable of doing. Learning turns uncertainty into opportunity.
I seek knowledge that expands my perspective and sharpens my mind. Learning helps me see beyond assumptions and think more clearly. A growing mind keeps my life dynamic.
I cultivate curiosity and intellectual growth every day. Learning gives me the ability to understand complex ideas and make thoughtful decisions. A strong mind supports every area of my life.
I actively expand my understanding through new knowledge and skills. Learning helps me grow beyond limitations and stay adaptable. Each insight builds momentum for the future.
I build a life shaped by curiosity and continuous improvement. Learning helps me understand the world more deeply and navigate it more wisely. A growing mind makes every experience richer.
""",
    "Health & Energy": """
I maintain my health and energy so I can show up fully in every part of life. When my body and mind are strong, everything else becomes easier to handle. This foundation allows me to live with focus, resilience, and confidence.
I care for my physical and mental energy so I can think clearly and act with intention. When my energy is steady, I avoid reacting to stress and instead move through life with control and clarity. This keeps my daily life stable and productive.
I prioritize my health because it supports every other area of my life. When my body feels strong and my energy is balanced, I can pursue my goals with consistency. This allows me to live with strength and longevity.
I build habits that protect my health and energy every day. When I care for my body and mind, I gain the stamina needed to handle challenges. This keeps me capable and resilient over the long term.
I treat my health as a core foundation of my life. When my energy is strong, I can focus on what matters most without constant fatigue or stress. This allows me to move through life with stability and strength.
I invest in my health so my life is not limited by low energy or preventable problems. When my body and mind function well, I gain freedom to pursue opportunities. This helps me live a more capable and active life.
I strengthen my health so I can handle life's responsibilities with confidence. When my energy is steady, I approach challenges with clarity instead of exhaustion. This helps me stay dependable and effective.
I protect my physical and mental well-being so I can sustain progress in every area of life. When my energy is balanced, I avoid burnout and remain consistent. This allows me to maintain momentum over time.
I care for my body and mind so I can stay present and engaged in daily life. When my health is strong, I experience life with greater clarity and enjoyment. This creates a more grounded and fulfilling life.
I build a strong health foundation so I can handle both opportunities and challenges. When my energy is reliable, I can take action instead of hesitating from fatigue. This keeps me capable and ready for what life brings.
I maintain my health because it shapes how I experience each day. When my energy is stable, I move through life with focus and calm instead of constant strain. This helps me feel balanced and capable.
I strengthen my health so I can bring my best self to the people and responsibilities in my life. When my energy is high and my mind is clear, I contribute more effectively. This improves both my performance and my relationships.
I take care of my health so I can live with strength and independence. When my body and mind are supported, I avoid many problems that limit my freedom later. This keeps my life stable and self-directed.
I prioritize my health because it determines the quality of my daily life. When my energy is consistent, I can focus on meaningful goals instead of managing constant fatigue. This creates a more productive and satisfying life.
I support my health so I can stay resilient through stress and change. When my body and mind are well cared for, I recover faster and adapt more easily. This keeps me steady through challenges.
I maintain strong health habits so my energy supports my ambitions. When I feel physically and mentally capable, I take action with greater confidence. This allows me to move forward without unnecessary limits.
I care for my health because it allows me to enjoy life fully. When my energy is high and my body feels strong, everyday experiences become more rewarding. This creates a life that feels vibrant and engaged.
I strengthen my health so I can sustain long-term progress in life. When my energy is balanced, I avoid the cycles of burnout and recovery. This helps me stay consistent and reliable.
I invest in my health because it multiplies my ability to live well. When my body and mind are supported, I perform better and feel better. This creates stability across every part of my life.
I treat my health as a responsibility to myself and my future. When my energy is strong and my body functions well, I have greater freedom and opportunity. This allows me to live a longer, stronger, and more capable life.
""",
    "Love & Relationships": """
Strong relationships give my life meaning and depth. When I invest in the people I care about, I feel supported and connected instead of isolated. These bonds shape the quality of my life.
Healthy relationships help me grow into a better person. When I communicate honestly and show up with care, trust deepens and conflict becomes constructive. This area strengthens the foundation of my life.
Connection with others keeps my life balanced and grounded. When my relationships are strong, I face challenges with more resilience and perspective. The people around me make life richer and more meaningful.
Investing in my relationships creates belonging and stability. When I nurture these connections, life feels less stressful and more supportive. Strong relationships help everything else in life work better.
Meaningful relationships bring joy, support, and shared experience. When I care for the people in my life, I create memories and trust that last far beyond individual moments. This area shapes the emotional quality of my life.
Healthy relationships help me feel understood and valued. When I listen well and communicate clearly, trust grows and problems become easier to solve. This creates stability across my life.
The people I care about shape who I become. When I invest in these relationships with intention, I build a circle of trust, support, and encouragement. These connections strengthen every part of my life.
Strong relationships reduce loneliness and create lasting support. When I consistently show up for others, I build trust that grows over time. This area gives my life deeper meaning.
My relationships influence my happiness and well-being. When I nurture connection and resolve conflict with care, life feels calmer and more fulfilling. These bonds make life more resilient.
Healthy relationships create emotional security and belonging. When I invest time and care into them, I build trust that supports me through both good times and challenges. This area anchors my life.
The strength of my relationships shapes the quality of my daily life. When I communicate openly and support others, connection becomes deeper and more rewarding. This makes life feel richer.
Relationships help me grow, learn, and stay grounded. When I invest in them intentionally, I create a network of trust and encouragement. This strengthens my sense of belonging.
Connection with others gives life warmth and meaning. When I nurture relationships consistently, trust grows and challenges feel easier to navigate. This area supports my emotional well-being.
Strong relationships create support that no achievement can replace. When I prioritize connection, I build bonds that make life more stable and fulfilling. These relationships enrich every season of life.
Healthy relationships help me show up fully in life. When I care for the people around me, trust grows and conflict becomes manageable. This strengthens my sense of belonging.
Relationships bring perspective and shared experience. When I invest time and care into them, I build bonds that deepen my life and strengthen my resilience. These connections make life meaningful.
Connection helps me stay grounded in what truly matters. When I nurture relationships with honesty and attention, trust and understanding grow. This area improves the emotional quality of my life.
Strong relationships help me feel supported and valued. When I consistently show care and attention, I create trust that lasts through challenges. These bonds shape the strength of my life.
My relationships influence my happiness more than almost anything else. When I nurture them intentionally, connection deepens and life feels less reactive. This area keeps my life balanced.
Healthy relationships help me live with more empathy and understanding. When I invest in connection and communication, trust grows and life becomes more fulfilling. These bonds strengthen every part of my life.
""",
    "Lifestyle & Experiences": """
I make space in my life for exploration and new experiences. Trying new things keeps life interesting and prevents my days from feeling repetitive. When this area is strong, I feel energized, curious, and fully engaged in the world around me.
I actively seek experiences that expand my perspective. Exploring new places, ideas, and activities keeps my mind open and my life dynamic. This reminds me that life is meant to be lived, not just managed.
I create a life that includes discovery and adventure. Even small experiences bring variety and meaning to everyday life. When I prioritize this area, my life feels richer and more memorable.
I choose to experience life instead of simply moving through routines. New environments, people, and activities help me stay curious and engaged. This keeps my life vibrant rather than predictable.
I keep curiosity alive through exploration and meaningful experiences. Trying new things strengthens creativity and keeps my perspective fresh. When I invest in this area, life feels expansive instead of narrow.
I regularly step outside familiar routines to experience something new. These moments of discovery bring excitement and inspiration into my life. They remind me that growth often begins with exploration.
I prioritize experiences that make life feel meaningful and memorable. Exploring the world around me strengthens my appreciation for everyday life. This keeps my life balanced between responsibility and enjoyment.
I intentionally create moments that make life enjoyable and interesting. Exploring new places, hobbies, and activities keeps my perspective fresh. This helps me build a life filled with stories and meaningful memories.
I give myself permission to experience life fully. Exploring new environments and activities helps me stay energized and inspired. When this area grows, my life feels more alive and fulfilling.
I invest time in experiences that broaden my understanding of the world. New perspectives deepen my appreciation for life and the people around me. This keeps my thinking flexible and my life interesting.
I keep my life dynamic by exploring ideas, places, and experiences. Each new experience adds depth and perspective to my life. When I nurture this area, life feels exciting instead of repetitive.
I make curiosity and discovery part of my everyday life. Small experiences create momentum toward a more vibrant and meaningful life. This helps me stay engaged with the world around me.
I build a life filled with experiences that inspire and energize me. Exploring new opportunities keeps my perspective fresh and creative. This strengthens both my mindset and my sense of adventure.
I stay open to new experiences that bring variety and meaning into my life. Trying new things keeps me growing and prevents life from becoming stagnant. This area keeps my life feeling expansive and alive.
I make exploration a regular part of my life. New experiences challenge my assumptions and expand my perspective. When this area is strong, life feels more interesting and rewarding.
I pursue experiences that create memorable moments and personal growth. Exploring new activities and environments keeps life engaging. This reminds me that meaningful living includes both progress and enjoyment.
I choose to remain curious about the world around me. New experiences help me see life from different perspectives. This keeps my life interesting, balanced, and full of possibility.
I create a lifestyle that includes exploration, creativity, and discovery. New experiences stimulate my mind and bring variety into my life. When this area grows, I feel more energized and inspired.
I allow space in my life for experiences that expand my perspective. Trying new things strengthens curiosity and personal growth. This helps me build a life that feels full rather than routine.
I intentionally seek experiences that bring joy, learning, and discovery. Exploring new places, ideas, and activities keeps life meaningful. When I strengthen this area, my life becomes richer and more fulfilling.
""",
    "Mindset & Resilience": """
I maintain a steady mindset so I can respond to challenges with clarity instead of reaction. When my thinking stays grounded, my decisions improve and my life feels more stable.
I strengthen my resilience so pressure does not control my behavior. When my mindset is strong, setbacks become lessons instead of barriers.
I cultivate calm thinking so I can handle uncertainty with confidence. A stable mindset allows me to move forward even when conditions are difficult.
I build emotional resilience so stress does not dictate my actions. When I stay balanced internally, I navigate challenges with greater clarity and strength.
I develop a mindset that adapts and grows through difficulty. When I respond thoughtfully instead of reactively, progress becomes consistent.
I strengthen my mental discipline so distractions and negative thinking do not derail my progress. A focused mindset allows me to keep moving forward.
I maintain perspective so temporary setbacks do not feel permanent. When I stay grounded, I make better decisions and recover faster.
I train my thinking to stay constructive during pressure. When my mindset remains steady, my actions become more effective.
I reinforce resilience so I can handle both success and failure with balance. This steadiness allows me to stay consistent over time.
I practice self-awareness so I recognize patterns in my thoughts and reactions. When I understand my mindset, I can guide it instead of being controlled by it.
I strengthen my inner stability so external events do not constantly disrupt my direction. A resilient mindset keeps my progress steady.
I develop patience with challenges so growth happens without unnecessary stress. When my mindset remains calm, solutions appear more clearly.
I maintain a thoughtful mindset so I respond with intention instead of impulse. This clarity allows me to move through challenges with confidence.
I cultivate resilience so difficult moments strengthen rather than weaken my progress. A strong mindset allows me to continue forward with purpose.
I strengthen my ability to recover from setbacks quickly. When my mindset stays adaptable, obstacles lose their power to stop progress.
I reinforce optimism grounded in reality so I can see opportunities within challenges. This perspective keeps momentum moving forward.
I maintain emotional balance so stress does not spread into every part of my life. When my mindset stays centered, everything else becomes easier to manage.
I train my thinking to remain constructive and solution-focused. This mindset turns challenges into problems that can be solved.
I develop resilience so uncertainty does not create paralysis. When my mindset stays strong, I continue moving forward with clarity.
I strengthen my mindset so I remain calm, thoughtful, and capable under pressure. This stability allows me to make better choices and sustain progress.
""",
    "Service & Impact": """
I use my time, skills, and resources to help others and improve the communities around me. Contributing beyond myself gives my life deeper meaning and reminds me that my actions can create real change.
I show up for others and look for ways to make life better for the people around me. When I contribute and serve, my life feels more purposeful and connected.
I use what I have to create positive impact where I can. Helping others grow, succeed, or overcome challenges strengthens both my community and my own sense of purpose.
I choose to contribute instead of just consume. By helping others and supporting meaningful causes, my actions create ripple effects that extend beyond my own life.
I make a difference through small acts of service and support. When I invest in people and communities, I help create a world that is stronger, kinder, and more resilient.
I use my abilities and opportunities to lift others when I can. Contributing to something bigger than myself brings deeper fulfillment and perspective.
I look for ways each day to help, support, or encourage someone else. Living this way reminds me that impact is built through consistent small actions.
I choose to leave people and places better than I found them. Contributing to the wellbeing of others creates a lasting sense of meaning and responsibility.
I invest my energy in causes and people that matter. When I contribute beyond myself, my life gains direction and purpose that goes beyond personal success.
I use my voice, effort, and influence to create positive change. Helping others move forward strengthens the communities and systems we all depend on.
I support others in ways that help them grow, succeed, and feel valued. When I contribute to someone else's progress, I help build a stronger and more connected world.
I take responsibility for contributing where I can instead of waiting for someone else to act. Service gives my life purpose and connects my daily actions to something meaningful.
I bring generosity, support, and encouragement into the lives of others. By contributing in small ways each day, I help create lasting positive impact.
I invest in people and communities that need support. When I contribute with intention, I help build a future that benefits more than just myself.
I use my time and abilities to create opportunities for others. Helping people succeed gives my life a deeper sense of purpose and meaning.
I contribute my effort to causes that improve lives and strengthen communities. Knowing that my actions help others gives my work greater significance.
I choose to give back instead of only moving forward for myself. Supporting others creates balance, perspective, and fulfillment in my life.
I look for ways to help others overcome challenges or move closer to their goals. When I serve others, I create meaning that goes far beyond personal achievement.
I take pride in contributing to something bigger than my own success. Helping others thrive strengthens both my community and my sense of purpose.
I use my daily actions to create positive influence in the lives of others. Contributing consistently reminds me that meaningful impact is built one step at a time.
""",
    "Home & Life": """
My home supports my clarity and peace. When my environment is organized and cared for, my mind is calmer and daily life feels lighter.
My home is a place of stability and order. Maintaining it well helps everything else in life run more smoothly.
I take care of the place where my life happens. A well-maintained home creates calm, focus, and energy for the things that matter most.
My environment reflects how I live. When my space is clean, functional, and intentional, my days feel more grounded and productive.
I maintain a home that supports rest and clarity. When my surroundings are in order, I can think clearly and move through the day with ease.
My living space works for me, not against me. Keeping it organized and functional reduces friction and frees my energy for more important things.
I care for my home as the foundation of daily life. A steady environment gives me the stability to focus on growth and progress.
My home is a place that restores me. When it is calm and cared for, it helps me recharge and show up better in every part of life.
I create an environment that makes life easier. Order and simplicity at home allow me to focus on what truly matters.
I take pride in the place where I live. Caring for it builds discipline and creates a space that supports my well-being.
My home supports both rest and productivity. Maintaining it well helps my days start and end with clarity and calm.
I keep my environment intentional and supportive. A well-run home creates stability that carries into every other part of life.
My space reflects the life I am building. When I maintain it with care, everything else feels more aligned and manageable.
I create a home that feels welcoming and steady. This foundation helps me stay grounded even when life becomes busy.
I maintain a space that supports both focus and recovery. A healthy environment makes it easier to sustain progress every day.
My home is the base from which my life moves forward. Keeping it in order strengthens my ability to live intentionally.
I value the systems that make daily life work. Maintaining my home creates stability that reduces stress and confusion.
My environment shapes how I feel and think. When I care for it well, I feel calmer, clearer, and more capable.
My home is a place where life can unfold smoothly. Keeping it organized and maintained helps each day flow more naturally.
I treat my home as a foundation for a well-lived life. When it is stable and cared for, everything else becomes easier to manage.
"""
]

fileprivate let fulfillmentStartIdentitySuggestionCSV = """
fulfillment_area,identity
Career & Business,Strategic Leader
Career & Business,Visionary Builder
Career & Business,Disciplined Professional
Career & Business,Impactful Executive
Career & Business,Entrepreneurial Thinker
Career & Business,Empowering Manager
Career & Business,Decisive Operator
Career & Business,Results Driver
Career & Business,Creative Innovator
Career & Business,Focused Producer
Career & Business,Respected Professional
Career & Business,Opportunity Creator
Career & Business,Market Builder
Career & Business,Team Champion
Career & Business,Trusted Advisor
Career & Business,Problem Solver
Career & Business,Strategic Planner
Career & Business,Value Creator
Career & Business,High Performer
Career & Business,Efficient Operator
Career & Business,Innovative Thinker
Career & Business,Relentless Executor
Career & Business,Growth Architect
Career & Business,Productive Builder
Career & Business,Industry Leader
Career & Business,Forward Thinker
Career & Business,Operational Expert
Career & Business,Decision Maker
Career & Business,Outcome Producer
Career & Business,Opportunity Finder
Career & Business,Smart Negotiator
Career & Business,Influential Communicator
Career & Business,Brand Builder
Career & Business,Revenue Generator
Career & Business,Strategic Networker
Career & Business,Confident Presenter
Career & Business,Skilled Operator
Career & Business,Disciplined Builder
Career & Business,Thoughtful Leader
Career & Business,Trusted Partner
Career & Business,Opportunity Maximizer
Career & Business,Impact Driver
Career & Business,Creative Builder
Career & Business,Focused Achiever
Career & Business,Vision Executor
Career & Business,Professional Craftsman
Career & Business,Organized Operator
Career & Business,Market Strategist
Career & Business,Execution Expert
Career & Business,Influential Leader

Faith & Spirituality,Prayer Warrior
Faith & Spirituality,Faithful Servant
Faith & Spirituality,Devoted Believer
Faith & Spirituality,Scripture Student
Faith & Spirituality,Spiritual Seeker
Faith & Spirituality,Faith Builder
Faith & Spirituality,Hope Carrier
Faith & Spirituality,Prayerful Leader
Faith & Spirituality,Humble Follower
Faith & Spirituality,Servant Leader
Faith & Spirituality,Faithful Steward
Faith & Spirituality,Compassionate Helper
Faith & Spirituality,Spiritual Disciple
Faith & Spirituality,Worshipper
Faith & Spirituality,Faith Mentor
Faith & Spirituality,Scripture Learner
Faith & Spirituality,Faithful Witness
Faith & Spirituality,Prayerful Friend
Faith & Spirituality,Encouraging Believer
Faith & Spirituality,Faithful Listener
Faith & Spirituality,Faithful Disciple
Faith & Spirituality,Spiritual Builder
Faith & Spirituality,Hopeful Follower
Faith & Spirituality,Prayerful Thinker
Faith & Spirituality,Faithful Encourager
Faith & Spirituality,Devoted Servant
Faith & Spirituality,Spiritual Guide
Faith & Spirituality,Faithful Student
Faith & Spirituality,Grateful Believer
Faith & Spirituality,Faithful Companion
Faith & Spirituality,Prayerful Steward
Faith & Spirituality,Spirit Led Leader
Faith & Spirituality,Faith Builder
Faith & Spirituality,Compassionate Disciple
Faith & Spirituality,Faithful Friend
Faith & Spirituality,Faithful Teacher
Faith & Spirituality,Spiritual Explorer
Faith & Spirituality,Faithful Encourager
Faith & Spirituality,Prayerful Seeker
Faith & Spirituality,Faithful Supporter
Faith & Spirituality,Hopeful Leader
Faith & Spirituality,Faithful Listener
Faith & Spirituality,Faithful Witness
Faith & Spirituality,Spiritual Student
Faith & Spirituality,Faithful Servant
Faith & Spirituality,Prayerful Helper
Faith & Spirituality,Faithful Follower
Faith & Spirituality,Spirit Guided Thinker
Faith & Spirituality,Faith Builder
Faith & Spirituality,Faithful Intercessor

Wealth & Finance,Wealth Builder
Wealth & Finance,Disciplined Investor
Wealth & Finance,Smart Saver
Wealth & Finance,Financial Planner
Wealth & Finance,Opportunity Investor
Wealth & Finance,Capital Builder
Wealth & Finance,Strategic Earner
Wealth & Finance,Money Steward
Wealth & Finance,Wealth Architect
Wealth & Finance,Financial Optimizer
Wealth & Finance,Disciplined Saver
Wealth & Finance,Asset Builder
Wealth & Finance,Financial Strategist
Wealth & Finance,Opportunity Buyer
Wealth & Finance,Smart Investor
Wealth & Finance,Capital Allocator
Wealth & Finance,Income Builder
Wealth & Finance,Debt Eliminator
Wealth & Finance,Future Planner
Wealth & Finance,Financial Guardian
Wealth & Finance,Value Investor
Wealth & Finance,Opportunity Seeker
Wealth & Finance,Wealth Creator
Wealth & Finance,Financial Organizer
Wealth & Finance,Money Multiplier
Wealth & Finance,Strategic Spender
Wealth & Finance,Financial Builder
Wealth & Finance,Financial Learner
Wealth & Finance,Portfolio Builder
Wealth & Finance,Wealth Strategist
Wealth & Finance,Smart Allocator
Wealth & Finance,Income Optimizer
Wealth & Finance,Future Builder
Wealth & Finance,Financial Protector
Wealth & Finance,Capital Grower
Wealth & Finance,Financial Thinker
Wealth & Finance,Opportunity Planner
Wealth & Finance,Money Manager
Wealth & Finance,Wealth Designer
Wealth & Finance,Investment Student
Wealth & Finance,Financial Executor
Wealth & Finance,Strategic Investor
Wealth & Finance,Financial Builder
Wealth & Finance,Income Architect
Wealth & Finance,Wealth Planner
Wealth & Finance,Capital Builder
Wealth & Finance,Financial Navigator
Wealth & Finance,Money Strategist
Wealth & Finance,Investment Thinker
Wealth & Finance,Financial Stewardfulfillment_area,identity
Learning & Education,Focused Student
Learning & Education,Curious Learner
Learning & Education,Knowledge Seeker
Learning & Education,Thoughtful Scholar
Learning & Education,Lifelong Learner
Learning & Education,Deep Thinker
Learning & Education,Insight Hunter
Learning & Education,Idea Explorer
Learning & Education,Curiosity Driver
Learning & Education,Skill Builder
Learning & Education,Knowledge Builder
Learning & Education,Concept Master
Learning & Education,Learning Strategist
Learning & Education,Academic Builder
Learning & Education,Idea Synthesizer
Learning & Education,Reflective Learner
Learning & Education,Analytical Thinker
Learning & Education,Concept Explorer
Learning & Education,Curious Researcher
Learning & Education,Learning Architect
Learning & Education,Idea Connector
Learning & Education,Knowledge Architect
Learning & Education,Learning Optimizer
Learning & Education,Skill Developer
Learning & Education,Knowledge Practitioner
Learning & Education,Insight Builder
Learning & Education,Curious Investigator
Learning & Education,Idea Researcher
Learning & Education,Learning Builder
Learning & Education,Concept Strategist
Learning & Education,Idea Analyst
Learning & Education,Knowledge Expander
Learning & Education,Focused Scholar
Learning & Education,Learning Explorer
Learning & Education,Knowledge Integrator
Learning & Education,Learning Executor
Learning & Education,Insight Seeker
Learning & Education,Learning Innovator
Learning & Education,Intellectual Builder
Learning & Education,Knowledge Creator
Learning & Education,Thoughtful Researcher
Learning & Education,Learning Synthesizer
Learning & Education,Idea Builder
Learning & Education,Curiosity Explorer
Learning & Education,Knowledge Strategist
Learning & Education,Skill Explorer
Learning & Education,Knowledge Analyst
Learning & Education,Insight Creator
Learning & Education,Concept Builder
Learning & Education,Learning Thinker

Love & Relationships,Loving Partner
Love & Relationships,Supportive Partner
Love & Relationships,Loyal Friend
Love & Relationships,Present Listener
Love & Relationships,Encouraging Partner
Love & Relationships,Compassionate Friend
Love & Relationships,Attentive Listener
Love & Relationships,Trust Builder
Love & Relationships,Relationship Builder
Love & Relationships,Family Champion
Love & Relationships,Empathetic Friend
Love & Relationships,Respectful Communicator
Love & Relationships,Caring Partner
Love & Relationships,Patient Listener
Love & Relationships,Connection Builder
Love & Relationships,Relationship Nurturer
Love & Relationships,Kind Companion
Love & Relationships,Honest Communicator
Love & Relationships,Dependable Partner
Love & Relationships,Trustworthy Friend
Love & Relationships,Affectionate Partner
Love & Relationships,Supportive Listener
Love & Relationships,Thoughtful Friend
Love & Relationships,Respectful Partner
Love & Relationships,Encouraging Companion
Love & Relationships,Loyal Companion
Love & Relationships,Relationship Investor
Love & Relationships,Kind Listener
Love & Relationships,Empathetic Partner
Love & Relationships,Compassionate Listener
Love & Relationships,Family Builder
Love & Relationships,Present Partner
Love & Relationships,Connection Creator
Love & Relationships,Relationship Guardian
Love & Relationships,Understanding Friend
Love & Relationships,Affirming Partner
Love & Relationships,Thoughtful Companion
Love & Relationships,Encouraging Listener
Love & Relationships,Trust Cultivator
Love & Relationships,Connection Champion
Love & Relationships,Kindhearted Friend
Love & Relationships,Patient Partner
Love & Relationships,Relationship Steward
Love & Relationships,Supportive Companion
Love & Relationships,Family Supporter
Love & Relationships,Respectful Listener
Love & Relationships,Connection Nurturer
Love & Relationships,Compassionate Partner
Love & Relationships,Loving Companion
Love & Relationships,Relationship Builder

Health & Energy,Disciplined Athlete
Health & Energy,Energized Mover
Health & Energy,Healthy Eater
Health & Energy,Strong Body Builder
Health & Energy,Daily Exerciser
Health & Energy,Endurance Builder
Health & Energy,Strength Builder
Health & Energy,Active Lifestyle
Health & Energy,Rest Prioritizer
Health & Energy,Hydration Champion
Health & Energy,Healthy Sleeper
Health & Energy,Body Optimizer
Health & Energy,Energetic Performer
Health & Energy,Movement Advocate
Health & Energy,Health Builder
Health & Energy,Wellness Strategist
Health & Energy,Resilient Athlete
Health & Energy,Daily Walker
Health & Energy,Fit Professional
Health & Energy,Energy Guardian
Health & Energy,Healthy Routine Builder
Health & Energy,Strong Performer
Health & Energy,Body Steward
Health & Energy,Recovery Prioritizer
Health & Energy,Movement Builder
Health & Energy,Endurance Athlete
Health & Energy,Strength Seeker
Health & Energy,Health Investor
Health & Energy,Daily Trainer
Health & Energy,Wellness Builder
Health & Energy,Body Maintainer
Health & Energy,Active Explorer
Health & Energy,Energy Optimizer
Health & Energy,Healthy Performer
Health & Energy,Movement Leader
Health & Energy,Strength Developer
Health & Energy,Body Protector
Health & Energy,Energy Builder
Health & Energy,Wellness Champion
Health & Energy,Healthy Thinker
Health & Energy,Performance Builder
Health & Energy,Resilient Performer
Health & Energy,Daily Mover
Health & Energy,Healthy Habit Builder
Health & Energy,Energy Architect
Health & Energy,Active Builder
Health & Energy,Body Builder
Health & Energy,Wellness Practitioner
Health & Energy,Strength Strategist
Health & Energy,Energized Achiever

Lifestyle & Experiences,Experience Explorer
Lifestyle & Experiences,Life Adventurer
Lifestyle & Experiences,Curious Explorer
Lifestyle & Experiences,Creative Hobbyist
Lifestyle & Experiences,Travel Explorer
Lifestyle & Experiences,Experience Builder
Lifestyle & Experiences,Adventure Seeker
Lifestyle & Experiences,Joy Creator
Lifestyle & Experiences,Curious Adventurer
Lifestyle & Experiences,Life Explorer
Lifestyle & Experiences,Experience Designer
Lifestyle & Experiences,Creative Explorer
Lifestyle & Experiences,Leisure Creator
Lifestyle & Experiences,Joyful Explorer
Lifestyle & Experiences,Experience Collector
Lifestyle & Experiences,Life Enthusiast
Lifestyle & Experiences,Adventure Builder
Lifestyle & Experiences,Curious Traveler
Lifestyle & Experiences,Creative Adventurer
Lifestyle & Experiences,Joy Builder
Lifestyle & Experiences,Life Designer
Lifestyle & Experiences,Experience Seeker
Lifestyle & Experiences,Curiosity Explorer
Lifestyle & Experiences,Creative Discoverer
Lifestyle & Experiences,Life Optimizer
Lifestyle & Experiences,Experience Architect
Lifestyle & Experiences,Joy Explorer
Lifestyle & Experiences,Creative Hobbyist
Lifestyle & Experiences,Adventure Creator
Lifestyle & Experiences,Life Explorer
Lifestyle & Experiences,Experience Innovator
Lifestyle & Experiences,Curiosity Builder
Lifestyle & Experiences,Joyful Adventurer
Lifestyle & Experiences,Experience Planner
Lifestyle & Experiences,Creative Traveler
Lifestyle & Experiences,Life Creator
Lifestyle & Experiences,Adventure Explorer
Lifestyle & Experiences,Experience Enthusiast
Lifestyle & Experiences,Joy Seeker
Lifestyle & Experiences,Curious Discoverer
Lifestyle & Experiences,Creative Experience
Lifestyle & Experiences,Life Adventurer
Lifestyle & Experiences,Experience Builder
Lifestyle & Experiences,Joy Architect
Lifestyle & Experiences,Curious Life Explorer
Lifestyle & Experiences,Adventure Enthusiast
Lifestyle & Experiences,Experience Creator
Lifestyle & Experiences,Creative Adventurer
Lifestyle & Experiences,Life Discoverer
Lifestyle & Experiences,Joy Builderfulfillment_area,identity
Mindset & Resilience,Calm Thinker
Mindset & Resilience,Resilient Builder
Mindset & Resilience,Optimistic Realist
Mindset & Resilience,Focused Thinker
Mindset & Resilience,Steady Mind
Mindset & Resilience,Disciplined Mind
Mindset & Resilience,Growth Thinker
Mindset & Resilience,Reflective Thinker
Mindset & Resilience,Perspective Builder
Mindset & Resilience,Emotional Navigator
Mindset & Resilience,Inner Stabilizer
Mindset & Resilience,Clarity Seeker
Mindset & Resilience,Mindful Observer
Mindset & Resilience,Thought Architect
Mindset & Resilience,Calm Strategist
Mindset & Resilience,Patient Thinker
Mindset & Resilience,Focused Mind
Mindset & Resilience,Resilient Optimist
Mindset & Resilience,Perspective Keeper
Mindset & Resilience,Steady Builder
Mindset & Resilience,Reflective Builder
Mindset & Resilience,Calm Decision Maker
Mindset & Resilience,Disciplined Thinker
Mindset & Resilience,Resilience Builder
Mindset & Resilience,Clear Thinker
Mindset & Resilience,Mindset Builder
Mindset & Resilience,Thoughtful Observer
Mindset & Resilience,Inner Architect
Mindset & Resilience,Clarity Builder
Mindset & Resilience,Steady Optimist
Mindset & Resilience,Composed Thinker
Mindset & Resilience,Perspective Architect
Mindset & Resilience,Focused Observer
Mindset & Resilience,Emotional Strategist
Mindset & Resilience,Resilient Navigator
Mindset & Resilience,Steady Reflector
Mindset & Resilience,Patient Builder
Mindset & Resilience,Thoughtful Strategist
Mindset & Resilience,Clear Mind
Mindset & Resilience,Calm Observer
Mindset & Resilience,Resilient Thinker
Mindset & Resilience,Inner Stabilizer
Mindset & Resilience,Focused Responder
Mindset & Resilience,Clarity Architect
Mindset & Resilience,Steady Executor
Mindset & Resilience,Reflective Strategist
Mindset & Resilience,Grounded Thinker
Mindset & Resilience,Mindful Builder
Mindset & Resilience,Perspective Navigator
Mindset & Resilience,Composed Leader

Service & Impact,Community Contributor
Service & Impact,Generous Giver
Service & Impact,Helpful Neighbor
Service & Impact,Encouraging Voice
Service & Impact,Impact Builder
Service & Impact,Service Leader
Service & Impact,Community Builder
Service & Impact,Opportunity Sharer
Service & Impact,Supportive Ally
Service & Impact,Kindness Carrier
Service & Impact,Positive Influence
Service & Impact,Community Supporter
Service & Impact,Encouragement Giver
Service & Impact,Impact Creator
Service & Impact,Helpful Contributor
Service & Impact,Community Helper
Service & Impact,Impact Advocate
Service & Impact,Encouraging Leader
Service & Impact,Generosity Builder
Service & Impact,Service Contributor
Service & Impact,Positive Builder
Service & Impact,Community Champion
Service & Impact,Helpful Guide
Service & Impact,Kindness Builder
Service & Impact,Opportunity Connector
Service & Impact,Service Partner
Service & Impact,Community Ally
Service & Impact,Impact Supporter
Service & Impact,Encouragement Builder
Service & Impact,Service Advocate
Service & Impact,Helpful Mentor
Service & Impact,Community Uplifter
Service & Impact,Kindness Advocate
Service & Impact,Service Champion
Service & Impact,Impact Mentor
Service & Impact,Generous Supporter
Service & Impact,Positive Mentor
Service & Impact,Community Steward
Service & Impact,Service Builder
Service & Impact,Encouraging Mentor
Service & Impact,Impact Steward
Service & Impact,Community Connector
Service & Impact,Kindness Leader
Service & Impact,Service Helper
Service & Impact,Impact Contributor
Service & Impact,Encouragement Champion
Service & Impact,Generosity Leader
Service & Impact,Community Mentor
Service & Impact,Positive Contributor
Service & Impact,Service Steward

Home & Life,Organized Homemaker
Home & Life,Home Steward
Home & Life,Space Organizer
Home & Life,Life Organizer
Home & Life,Calm Environment Builder
Home & Life,Home Systems Builder
Home & Life,Household Manager
Home & Life,Order Creator
Home & Life,Home Maintainer
Home & Life,Clutter Eliminator
Home & Life,Environment Designer
Home & Life,Life Systems Builder
Home & Life,Home Caretaker
Home & Life,Order Builder
Home & Life,Household Organizer
Home & Life,Intentional Homemaker
Home & Life,Home Optimizer
Home & Life,Environment Builder
Home & Life,Space Curator
Home & Life,Order Steward
Home & Life,Home Architect
Home & Life,Household Builder
Home & Life,Life Stabilizer
Home & Life,Environment Maintainer
Home & Life,Home Guardian
Home & Life,Clarity Creator
Home & Life,Space Maintainer
Home & Life,Home Organizer
Home & Life,Life Simplifier
Home & Life,Household Steward
Home & Life,Environment Curator
Home & Life,Space Optimizer
Home & Life,Life Architect
Home & Life,Home Systems Manager
Home & Life,Order Designer
Home & Life,Household Stabilizer
Home & Life,Space Builder
Home & Life,Home Manager
Home & Life,Environment Organizer
Home & Life,Life Maintainer
Home & Life,Household Architect
Home & Life,Home Stabilizer
Home & Life,Space Steward
Home & Life,Order Guardian
Home & Life,Environment Simplifier
Home & Life,Home Builder
Home & Life,Household Curator
Home & Life,Life Organizer
Home & Life,Space Designer
Home & Life,Home Designer
"""

let fulfillmentStartIdentitySuggestionMap: [String: [String]] = {
    var map: [String: [String]] = [:]

    for rawLine in fulfillmentStartIdentitySuggestionCSV.components(separatedBy: .newlines) {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { continue }
        line = line
            .replacingOccurrences(of: "fulfillment_area,identity", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { continue }
        guard let commaIndex = line.firstIndex(of: ",") else { continue }

        let area = String(line[..<commaIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let identity = String(line[line.index(after: commaIndex)...])
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !area.isEmpty, !identity.isEmpty else { continue }

        var bucket = map[area, default: []]
        if !bucket.contains(where: { $0.caseInsensitiveCompare(identity) == .orderedSame }) {
            bucket.append(identity)
        }
        map[area] = bucket
    }

    return map
}()

let fulfillmentStartLittleWinCorpusByCategory: [String: String] = [
    "Career & Business": """
Plan top priorities
Review weekly goals
Deep work session
Clear email backlog
Follow up contact
Reach out connection
Send thank you note
Share useful idea
Post professional insight
Read industry article
Study new skill
Watch expert talk
Practice core skill
Improve work system
Organize task list
Update project plan
Document key process
Solve one problem
Make progress project
Finish small task
Prepare meeting notes
Schedule key meeting
Ask thoughtful question
Offer helpful feedback
Request feedback
Help teammate succeed
Mentor someone
Learn from mistake
Reflect on progress
Track key metric
Update resume
Update portfolio
Improve LinkedIn profile
Write new idea
Capture business idea
Research opportunity
Analyze competitor
Improve workflow
Automate small task
Declutter workspace
Review calendar
Protect focus block
Start earlier task
End day reflection
Plan tomorrow priorities
Learn from leader
Practice communication
Strengthen relationship
Support team member
Celebrate progress
""",
    "Faith & Spirituality": """
Morning prayer
Daily gratitude prayer
Scripture reading
Reflect on scripture
Write prayer intention
Quiet meditation
Practice stillness
Evening prayer
Gratitude reflection
Journal spiritual insight
Memorize verse
Listen faith podcast
Read spiritual book
Attend worship
Watch faith teaching
Serve someone
Encourage someone
Forgive someone
Practice humility
Practice patience
Practice compassion
Reflect on purpose
Ask for guidance
Confess mistakes
Express gratitude
Practice generosity
Reflect on blessings
Pray for others
Practice silence
End day reflection
""",
    "Wealth & Finance": """
Review daily spending
Track one expense
Log transactions
Check account balances
Review monthly budget
Reduce one expense
Skip unnecessary purchase
Transfer small savings
Round up savings
Automate savings
Review investment account
Read finance article
Learn investing concept
Review financial goal
Update net worth
Review subscriptions
Cancel unused subscription
Compare prices
Research investment idea
Plan future purchase
Reflect spending habits
Prepare weekly budget
Check credit score
Pay extra debt
Review financial plan
Capture business idea
Research income idea
Improve money system
Organize financial documents
Plan tomorrow spending
""",
    "Learning & Education": """
Read 10 pages
Study new concept
Review notes
Watch educational video
Listen learning podcast
Write key insight
Summarize lesson
Practice new skill
Research one topic
Ask thoughtful question
Save useful resource
Highlight key idea
Teach someone concept
Reflect learning
Review past lesson
Study vocabulary
Practice writing
Solve practice problem
Capture new idea
Explore new subject
Improve study system
Organize learning notes
Connect two ideas
Write learning summary
Practice memory recall
Review key principle
Read research article
Analyze expert thinkingx
Journal insight
Plan next learning
""",
    "Love & Relationships": """
Send thoughtful message
Express appreciation
Ask meaningful question
Listen fully
Give sincere compliment
Check in with friend
Plan quality time
Share encouragement
Write gratitude note
Reflect on relationship
Apologize sincerely
Celebrate small win
Offer support
Show physical affection
Pray for someone
Express love openly
Reconnect with friend
Remember important date
Share positive memory
Give undivided attention
Ask how they feel
Practice patience
Offer help
Resolve small tension
Reach out to family
Encourage someone's goal
Share honest feeling
Plan future activity
Practice empathy
Reflect on connection
""",
    "Lifestyle & Experiences": """
Try a new recipe
Explore new place
Take scenic walk
Watch inspiring film
Listen new music
Read fiction chapter
Visit local cafe
Try new hobby
Sketch something
Take photos outside
Plan weekend activity
Visit park
Learn simple recipe
Practice creative skill
Write travel idea
Explore new neighborhood
Visit museum online
Try new workout class
Journal about day
Declutter small area
Rearrange living space
Add plant to space
Light candle evening
Cook meal from scratch
Listen new podcast
Start small project
Practice photography
Visit local event
Learn dance move
Write creative idea
Take relaxing bath
Spend time outdoors
Try new tea or coffee
Practice instrument
Explore nature trail
Create playlist
Write bucket list idea
Plan day trip
Explore new bookstore
Sketch travel idea
Watch documentary
Try new art style
Practice cooking skill
Learn fun fact
Start hobby research
Walk somewhere new
Visit scenic view
Capture moment photo
Reflect on experience
Share experience story
""",
    "Mindset & Resilience": """
Write one gratitude
Reflect on small win
Reframe negative thought
Take five deep breaths
Pause before reacting
Write one affirmation
Journal one insight
Notice one positive moment
Accept one imperfection
Practice patience moment
Step away from stress
Focus on present moment
Name current emotion
Release one worry
Reflect on lesson learned
Let go of small frustration
Practice calm breathing
Choose optimistic thought
Take mindful pause
Recognize personal progress
Write one encouraging note
Focus on controllable action
Acknowledge personal strength
Practice self compassion
Observe thoughts quietly
Identify stress trigger
Write one perspective shift
Forgive small mistake
Celebrate effort today
Accept what cannot change
Find meaning in challenge
Note one personal value
Choose calm response
Reset mindset after setback
Pause to reflect
Take mental reset break
Write short reflection
Observe reaction pattern
Appreciate small progress
Focus on solution step
Encourage yourself kindly
Release unnecessary pressure
Notice mental habit
Practice mindful awareness
Slow down breathing
Reconnect with purpose
Choose growth mindset
Accept uncertainty calmly
Focus on next step
End day with reflection
""",
    "Service & Impact": """
Help someone today
Offer encouragement
Share helpful advice
Volunteer small task
Donate small amount
Support local business
Recommend helpful resource
Mentor briefly
Answer someone's question
Share useful knowledge
Introduce two people
Offer to assist coworker
Write thank you message
Check in on someone
Give thoughtful feedback
Share inspiring idea
Encourage someone's goal
Offer genuine praise
Teach small skill
Share opportunity
Promote someone's work
Participate in community group
Support charitable cause
Pick up litter
Help neighbor
Share helpful article
Connect someone to resource
Listen to someone's problem
Offer time to help
Support community event
Spread positive message
Encourage someone struggling
Give credit publicly
Amplify important cause
Offer guidance
Participate in service project
Donate useful item
Write appreciation note
Share learning with others
Support small creator
Help organize group effort
Share job opportunity
Encourage team morale
Advocate for fairness
Offer practical help
Teach helpful concept
Recognize someone's effort
Share community resource
Help someone solve problem
Reflect on how you helped
""",
    "Home & Life": """
Make the bed
Tidy one surface
Wash a few dishes
Empty trash bin
Start laundry load
Fold clean clothes
Put items back in place
Clean kitchen counter
Wipe bathroom sink
Sweep small area
Vacuum one room
Organize one drawer
Declutter five items
Sort incoming mail
Restock household item
Clean refrigerator shelf
Water house plants
Open windows for fresh air
Replace used towels
Clean dining table
Wipe light switches
Clean door handles
Organize entryway
Prepare tomorrow's outfit
Prep simple meal
Refill water bottles
Review household schedule
Plan weekly groceries
Create simple meal plan
Write quick to do list
Put laundry away
Clean small spill
Organize digital files
Backup important file
Review calendar events
Prepare bag for tomorrow
Restock pantry item
Check household supplies
Reset living room
Clean mirror
Dust small surface
Replace burned out bulb
Check smoke detector
Prepare coffee setup
Sort recycling
Review bills
Pay small bill
Schedule needed errand
Prepare tomorrow's plan
End day home reset
"""
]

let fulfillmentStartHealthEnergyLittleWinFlags: [(activity: String, appleHealth: Bool)] = [
    ("10,000 steps", true),
    ("15 minute walk", true),
    ("30 minute workout", true),
    ("Morning stretch routine", false),
    ("Drink full glass of water", true),
    ("Eat a healthy breakfast", false),
    ("5 minute mobility work", false),
    ("10 minute yoga session", true),
    ("Short outdoor walk", true),
    ("Stand for 1 minute each hour", true),
    ("Take stairs instead of elevator", true),
    ("Log your meals", true),
    ("Eat a serving of vegetables", false),
    ("Eat a serving of fruit", false),
    ("15 minute cardio", true),
    ("HIIT workout", true),
    ("Strength training session", true),
    ("Light stretching before bed", false),
    ("5 minutes deep breathing", false),
    ("10 minutes meditation", true),
    ("Practice good posture", false),
    ("Take a hydration break", false),
    ("Drink 8 glasses of water", true),
    ("Walk after a meal", true),
    ("Avoid sugary snack", false),
    ("Healthy lunch choice", false),
    ("Cook a healthy meal", false),
    ("Spend time outside", false),
    ("Limit caffeine after afternoon", false),
    ("Sleep 7+ hours", true),
    ("Wind down before bed", false),
    ("Evening walk", true),
    ("Short bodyweight workout", true),
    ("Take movement break", true),
    ("Desk stretch break", false),
    ("Drink herbal tea instead of soda", false),
    ("Log body weight", true),
    ("Check resting heart rate", true),
    ("Track sleep quality", true),
    ("Cold shower or rinse", false),
    ("Foam roll muscles", false),
    ("Short bike ride", true),
    ("Light jog", true),
    ("Play recreational sport", true),
    ("Practice balance exercise", false),
    ("Reduce screen time before bed", false),
    ("Deep stretch session", false),
    ("Walk while on phone call", true),
    ("Park farther away and walk", true),
    ("Reflect on energy levels", false)
]

fileprivate let fulfillmentStartHealthEnergyAppleHealthLittleWins: Set<String> = {
    Set(
        fulfillmentStartHealthEnergyLittleWinFlags
            .filter { $0.appleHealth }
            .map { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    )
}()

struct FulfillmentStartView: View {
    private static let draftStorageKey = "fulfillment_start_onboarding_draft_v1"
    private static let fulfillmentInsightsPromptVersion = "onboarding_fulfillment_insights_v3"
    enum EntryMode {
        case onboarding
        case addSingleArea
        case lifeOSInsights
    }

    private struct DraftFulfillmentRow: Codable {
        var categoryID: UUID
        var updatedAt: Date
        var category: String
        var identity: String
        var vision: String
        var purpose: String
    }

    private struct DraftRoleRow: Codable {
        var id: UUID
        var categoryID: UUID
        var updatedAt: Date
        var role: String
        var rank: Int
    }

    private struct DraftFocusRow: Codable {
        var id: UUID
        var categoryID: UUID
        var updatedAt: Date
        var activity: String
        var rank: Int
    }

    private struct DraftResourceRow: Codable {
        var id: UUID
        var categoryID: UUID
        var updatedAt: Date
        var resource: String
        var rank: Int
    }

    private struct DraftPassionJoinRow: Codable {
        var id: UUID
        var passionID: UUID
        var categoryID: UUID
    }

    private struct DraftState: Codable {
        var stepRawValue: Int
        var visionIndex: Int
        var purposeIndex: Int
        var deepIndex: Int
        var passionIndex: Int?
        var priorityCategoryIDs: [UUID]
        var selectedCategoryNames: [String]
        var customCategoryNames: [String]
        var deletedDefaultCategoryNames: [String]
        var categoryColorKeys: [String: String]
        var visionDrafts: [String: String]
        var purposeDrafts: [String: String]
        var fulfillments: [DraftFulfillmentRow]
        var roles: [DraftRoleRow]
        var foci: [DraftFocusRow]
        var resources: [DraftResourceRow]
        var passionJoins: [DraftPassionJoinRow]
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query private var fulfillments: [Fulfillment]
    @Query private var roles: [FulfillmentRoles]
    @Query private var foci: [FulfillmentFocus]
    @Query private var resources: [FulfillmentResources]
    @Query private var passions: [Passion]
    @Query private var passionJoins: [PassionFulfillmentJoin]
    @Query(sort: \PassionScoreSnapshot.monthStartDate, order: .reverse) private var passionScoreSnapshots: [PassionScoreSnapshot]
    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \ActivePlanState.id, order: .forward) private var activePlanStates: [ActivePlanState]
    @Query(sort: \PlannedChunk.updatedAt, order: .reverse) private var allPlannedChunks: [PlannedChunk]
    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse) private var allPlannedActions: [PlannedChunkAction]
    @Query(sort: \Outcomes.updatedAt, order: .reverse) private var allOutcomes: [Outcomes]
    @Query(sort: \PlanLabel.category, order: .forward) private var planLabels: [PlanLabel]
    @AppStorage("fulfillment_start_insights_cache_v3") private var fulfillmentInsightsCacheStorage: String = ""
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true

    private let entryMode: EntryMode
    private let showsProgressStrip: Bool
    private let openedFromPersonalization: Bool

    init(
        entryMode: EntryMode = .onboarding,
        showsProgressStrip: Bool = true,
        openedFromPersonalization: Bool = false
    ) {
        self.entryMode = entryMode
        self.showsProgressStrip = showsProgressStrip
        self.openedFromPersonalization = openedFromPersonalization
    }


    @State private var step: Step = .intro
    @State private var visionIndex: Int = 0
    @State private var purposeIndex: Int = 0
    @State private var roleIndex: Int = 0
    @State private var passionIndex: Int = 0
    @State private var didOpenPriorities = false
    @State private var priorityCategoryIDs: [UUID] = []
    @State private var deepIndex: Int = 0

    @State private var visionDrafts: [UUID: String] = [:]
    @State private var purposeDrafts: [UUID: String] = [:]
    @State private var fulfillmentSnapshot: [Fulfillment] = []
    @State private var draftRoles: [DraftRoleRow] = []
    @State private var draftFoci: [DraftFocusRow] = []
    @State private var draftResources: [DraftResourceRow] = []
    @State private var draftPassionJoins: [DraftPassionJoinRow] = []
    @State private var roleEntry: String = ""
    @State private var focusEntry: String = ""
    @State private var resourceEntry: String = ""

    @State private var addingRole = false
    @State private var addingFocus = false
    @State private var addingResource = false
    @State private var addingCategory = false
    @State private var newCategoryText = ""
    @State private var selectedCategoryNames: [String] = []
    @State private var customCategoryNames: [String] = []
    @State private var deletedDefaultCategoryNames: Set<String> = []
    @State private var categoryColorKeys: [String: String] = [:]
    @State private var colorPickerCategory: String = ""
    @State private var showColorPicker = false
    @State private var isForcedColorPickerForProceed = false

    @State private var showNeedIdeasVision = false
    @State private var showNeedIdeasPurpose = false
    @State private var showNeedIdeasRoles = false
    @State private var showNeedIdeasLittleWins = false
    @State private var showNeedIdeasResources = false
    @State private var showNeedHelpCategories = false
    @State private var isPresentingLittleWinsAdvancedSheet = false
    @State private var littleWinsAdvancedCategoryID: UUID? = nil
    @State private var autoWriteMissionSuggestionsByCategoryID: [UUID: [String]] = [:]
    @State private var autoWritingMissionCategoryID: UUID? = nil
    @State private var autoWriteMissionErrorByCategoryID: [UUID: String] = [:]
    @State private var autoWriteMissionTroubleshootingByCategoryID: [UUID: String] = [:]
    @State private var autoWriteMissionLoadedKeys = Set<String>()
    @State private var autoWriteMissionSuggestionsCache: [String: [String]] = [:]
    @State private var autoWriteIdentitySuggestionsByCategoryID: [UUID: [IdentityAutoWriteSuggestion]] = [:]
    @State private var autoWritingIdentityCategoryID: UUID? = nil
    @State private var autoWriteIdentityErrorByCategoryID: [UUID: String] = [:]
    @State private var autoWriteIdentityTroubleshootingByCategoryID: [UUID: String] = [:]
    @State private var autoWriteIdentityLoadedKeys = Set<String>()
    @State private var autoWriteIdentitySuggestionsCache: [String: [IdentityAutoWriteSuggestion]] = [:]
    @State private var autoWriteLittleWinSuggestionsByCategoryID: [UUID: [LittleWinAutoWriteSuggestion]] = [:]
    @State private var autoWritingLittleWinCategoryID: UUID? = nil
    @State private var autoWriteLittleWinErrorByCategoryID: [UUID: String] = [:]
    @State private var autoWriteLittleWinTroubleshootingByCategoryID: [UUID: String] = [:]
    @State private var autoWriteLittleWinLoadedKeys = Set<String>()
    @State private var autoWriteLittleWinSuggestionsCache: [String: [LittleWinAutoWriteSuggestion]] = [:]
    @State private var fulfillmentInsightCards: [FulfillmentInsightCard] = []
    @State private var isGeneratingFulfillmentInsights = false
    @State private var fulfillmentInsightsErrorMessage: String? = nil
    @State private var fulfillmentInsightsNudgeMessage: String? = nil
    @State private var fulfillmentInsightsTroubleshootingMessage: String? = nil
    @State private var fulfillmentInsightsCache: [String: [FulfillmentInsightCard]] = [:]
    @State private var fulfillmentInsightsNudgeCache: [String: String] = [:]
    @State private var fulfillmentInsightsActiveRequestKey: String? = nil
    @State private var autoWriteOutlineAngle: Double = 0
    @State private var insightsOutlinePhase: CGFloat = 0
    @State private var autoWriteIconAnimating: Bool = false
    @State private var autoWriteIconAnimationTask: Task<Void, Never>? = nil

    @State private var showValidationHint = false
    @State private var validationHintText = ""
    @State private var hintWorkItem: DispatchWorkItem?
    @State private var previousAutosaveEnabled: Bool = true
    @State private var didFinalizeOnboarding = false
    @State private var didInitializeViewState = false
    @State private var ignoreBackUntil: Date = .distantPast
    @State private var usesDraftPersistence = false
    @State private var highlightInvalid = false
    @State private var invalidCategoryIDs = Set<UUID>()
    @State private var isAllSummaryExpanded = false
    @State private var addModeInitialActiveCategoryKeys = Set<String>()
    @State private var keyboardHeight: CGFloat = 0
    @State private var shouldScrollCreateCategoriesToInputAfterKeyboard = false
    private let createCategoriesCustomCategoryScrollID = "create_categories_custom_category_scroll_anchor"

    @FocusState private var focusedField: Field?
    private enum Field: Hashable {
        case category
        case vision
        case purpose
        case role
        case focus
        case resource
    }

    private enum Step: Int, CaseIterable {
        case intro = 0
        case createCategories
        case visionSweep
        case purposeSweep
        case roles
        case priorities
        case littleWins
        case resources
        case passions
        case summary
        case insights

        var title: String {
            switch self {
            case .intro: return "Set Fulfillment Areas"
            case .createCategories: return "Create Categories"
            case .visionSweep: return "Define Mission"
            case .purposeSweep: return "Define Mission"
            case .roles: return "Set Identity"
            case .priorities: return "Choose Your Focus"
            case .littleWins: return "List Daily Little Wins"
            case .resources: return "Note Resources"
            case .passions: return "Passions"
            case .summary: return "Summary"
            case .insights: return "LifeOS: Connecting the Dots"
            }
        }
    }

    private struct FulfillmentInsightCard: Identifiable, Hashable {
        let title: String
        let body: String
        var id: String { "\(title.lowercased())|\(body.lowercased())" }
    }

    private var isAddSingleAreaMode: Bool { entryMode == .addSingleArea }
    private var isLifeOSInsightsMode: Bool { entryMode == .lifeOSInsights }

    private var orderedFulfillments: [Fulfillment] {
        let baseRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        if !selectedCategoryNames.isEmpty {
            let all = baseRows
            let mapped = selectedCategoryNames.compactMap { selectedName in
                all.first { record in
                    categoryKey(record.category) == categoryKey(selectedName)
                }
            }
            if !mapped.isEmpty { return mapped }
        }
        var byID = Dictionary(uniqueKeysWithValues: baseRows.map { ($0.category_id, $0) })
        var ordered: [Fulfillment] = []
        for def in fulfillmentStartDefaultCategoryDefs {
            if let row = byID.removeValue(forKey: def.categoryID) {
                ordered.append(row)
            }
        }
        ordered.append(contentsOf: byID.values.sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending })
        return ordered
    }

    private var currentVisionRecord: Fulfillment? {
        guard orderedFulfillments.indices.contains(visionIndex) else { return nil }
        return orderedFulfillments[visionIndex]
    }

    private var currentPurposeRecord: Fulfillment? {
        guard orderedFulfillments.indices.contains(purposeIndex) else { return nil }
        return orderedFulfillments[purposeIndex]
    }

    private var roleCategoryIDs: [UUID] {
        orderedFulfillments.map(\.category_id)
    }

    private var currentRoleRecord: Fulfillment? {
        guard roleCategoryIDs.indices.contains(roleIndex) else { return nil }
        let categoryID = roleCategoryIDs[roleIndex]
        return orderedFulfillments.first(where: { $0.category_id == categoryID })
    }

    private var currentPassionRecord: Fulfillment? {
        guard roleCategoryIDs.indices.contains(passionIndex) else { return nil }
        let categoryID = roleCategoryIDs[passionIndex]
        return orderedFulfillments.first(where: { $0.category_id == categoryID })
    }

    private var deepCategoryIDs: [UUID] {
        isAddSingleAreaMode ? orderedFulfillments.map(\.category_id) : priorityCategoryIDs
    }

    private var currentDeepRecord: Fulfillment? {
        guard deepCategoryIDs.indices.contains(deepIndex) else { return nil }
        let categoryID = deepCategoryIDs[deepIndex]
        return orderedFulfillments.first(where: { $0.category_id == categoryID })
    }

    private var personalizationSnapshot: PersonalizationSnapshot? {
        PersonalizationStore.cachedContextForCurrentUser()?.current
    }

    private var progressCurrentStep: Int {
        if isAddSingleAreaMode {
            switch step {
            case .createCategories: return 1
            case .visionSweep: return 0
            case .purposeSweep: return 2
            case .roles: return 3
            case .littleWins: return 4
            case .passions: return 5
            case .resources: return 0
            default: return 0
            }
        }
        switch step {
        case .createCategories: return 1
        case .visionSweep: return 0
        case .purposeSweep: return 2
        case .roles: return 3
        case .priorities: return 4
        case .littleWins: return 5
        case .passions: return 6
        case .summary: return 7
        case .insights: return 8
        case .resources: return 0
        case .intro: return 0
        }
    }

    private var progressTotalSteps: Int {
        isAddSingleAreaMode ? 5 : 8
    }

    private var editorSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var rowSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var isScrollableStep: Bool {
        switch step {
        case .createCategories, .visionSweep, .purposeSweep, .roles, .littleWins, .passions, .summary:
            return true
        default:
            return false
        }
    }

    private var currentScrollAxes: Axis.Set { .vertical }

    private var isNextDisabled: Bool {
        switch step {
        case .createCategories:
            if isAddSingleAreaMode {
                return !(canAddSingleArea || shouldForceColorPickerBeforeProceed)
            }
            return !canStartOnboarding
        case .visionSweep:
            return false
        case .purposeSweep:
            guard let record = currentPurposeRecord else { return true }
            let text = (purposeDrafts[record.category_id] ?? record.category_purpose)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty
        case .roles:
            guard let record = currentRoleRecord else { return true }
            return getRoles(for: record).isEmpty
        case .priorities:
            if isAddSingleAreaMode { return false }
            return priorityCategoryIDs.isEmpty
        case .littleWins:
            if isAddSingleAreaMode { return false }
            guard let record = currentDeepRecord else { return true }
            return getFoci(for: record).isEmpty
        case .resources:
            return false
        case .passions:
            guard let record = currentPassionRecord else { return true }
            return selectedPassions(for: record.category_id).isEmpty
        default:
            return false
        }
    }

    private var summaryCanComplete: Bool {
        guard !(orderedFulfillments.isEmpty) else { return false }
        guard !priorityCategoryIDs.isEmpty else { return false }
        for id in roleCategoryIDs {
            guard let record = orderedFulfillments.first(where: { $0.category_id == id }) else { return false }
            if priorityCategoryIDs.contains(id), getFoci(for: record).isEmpty { return false }
            if selectedPassions(for: id).isEmpty { return false }
        }
        return true
    }

    private var canStartOnboarding: Bool {
        let names = selectedCategoryNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard (3...7).contains(names.count) else { return false }
        let uniqueCount = Set(names.map { $0.lowercased() }).count
        guard uniqueCount == names.count else { return false }
        return !hasCreateCategoriesColorConflict
    }

    private var canAddSingleArea: Bool {
        let names = selectedCategoryNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard names.count == 1 else { return false }
        let uniqueCount = Set(names.map { $0.lowercased() }).count
        guard uniqueCount == 1 else { return false }
        guard !hasCreateCategoriesColorConflict else { return false }
        guard !hasAddSingleAreaActiveColorConflict else { return false }
        return true
    }

    private var shouldForceColorPickerBeforeProceed: Bool {
        guard step == .createCategories, isAddSingleAreaMode else { return false }
        guard selectedCategoryNames.count == 1 else { return false }
        return hasAddSingleAreaActiveColorConflict
    }

    private var conflictingSelectedCategories: Set<String> {
        var grouped: [String: [String]] = [:]
        for category in selectedCategoryNames {
            let colorKey = categoryColorKeys[category] ?? rotatedColorKey(for: category)
            grouped[colorKey, default: []].append(category)
        }
        let duplicates = grouped.values.filter { $0.count > 1 }.flatMap { $0 }
        return Set(duplicates)
    }

    private var hasCreateCategoriesColorConflict: Bool {
        !conflictingSelectedCategories.isEmpty
    }

    private var activeCategoryColorKeys: Set<String> {
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        return Set(sourceRows.compactMap { row in
            let category = row.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !category.isEmpty else { return nil }
            return categoryColorKeys[category]
                ?? FulfillmentCategoryTheme.defaultColorKeys()[category]
                ?? "blue"
        })
    }

    private var hasAddSingleAreaActiveColorConflict: Bool {
        guard isAddSingleAreaMode else { return false }
        guard let category = selectedCategoryNames.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty else { return false }
        let selectedColorKey = categoryColorKeys[category]
            ?? FulfillmentCategoryTheme.defaultColorKeys()[category]
            ?? rotatedColorKey(for: category)
        return activeCategoryColorKeys.contains(selectedColorKey)
    }

    private func unavailableColorKeys(for category: String) -> Set<String> {
        let current = category.trimmingCharacters(in: .whitespacesAndNewlines)
        var keys = Set<String>()

        for otherCategory in selectedCategoryNames {
            let other = otherCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !other.isEmpty else { continue }
            guard other.caseInsensitiveCompare(current) != .orderedSame else { continue }
            let colorKey = categoryColorKeys[other]
                ?? FulfillmentCategoryTheme.defaultColorKeys()[other]
                ?? rotatedColorKey(for: other)
            keys.insert(colorKey)
        }

        if isAddSingleAreaMode {
            keys.formUnion(activeCategoryColorKeys)
        }

        return keys
    }

    private func availableColorOptions(for category: String) -> [FulfillmentCategoryTheme.PaletteOption] {
        let unavailable = unavailableColorKeys(for: category)
        return FulfillmentCategoryTheme.palette.filter { !unavailable.contains($0.key) }
    }

    private var availableCategoryNames: [String] {
        let defaults = fulfillmentStartSelectableDefaultCategories.filter { !deletedDefaultCategoryNames.contains($0) }
        let custom = customCategoryNames.filter { !fulfillmentStartSelectableDefaultCategories.contains($0) }
        return defaults + custom
    }

    private var createCategoriesListHeight: CGFloat {
        let baseRows = availableCategoryNames.count + 1 // + custom row/input row
        let contentHeight = CGFloat(baseRows) * 56 + 14
        return contentHeight + 28
    }

    private var existingActiveCategoryKeys: Set<String> {
        if isAddSingleAreaMode {
            return addModeInitialActiveCategoryKeys
        }
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        return Set(sourceRows.map(\.category).map { categoryKey($0) })
    }

    private var missingDefaultCategories: [String] {
        fulfillmentStartSelectableDefaultCategories.filter { defaultName in
            !availableCategoryNames.contains(where: { $0.caseInsensitiveCompare(defaultName) == .orderedSame })
        }
    }

    private var availableDefaultCategoryCount: Int {
        fulfillmentStartSelectableDefaultCategories.reduce(0) { count, defaultName in
            let exists = availableCategoryNames.contains(where: { $0.caseInsensitiveCompare(defaultName) == .orderedSame })
            return count + (exists ? 1 : 0)
        }
    }

    private var shouldShowRefreshButton: Bool {
        availableDefaultCategoryCount < fulfillmentStartSelectableDefaultCategories.count
    }

    private var onboardingColorCycleKeys: [String] {
        ["blue", "indigo", "green", "purple", "red", "orange"]
    }

    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }
    private var isCompactIntroLayout: Bool { screenHeight <= 740 || screenWidth <= 390 }
    private var introSubtextFont: Font { isCompactIntroLayout ? .system(size: 14) : .body }
    private let footerPinnedHeight: CGFloat = 68
    private let keyboardFloatingGap: CGFloat = 15
    private var isKeyboardVisible: Bool { keyboardHeight > 0 }
    private var keyboardScrollableBottomPadding: CGFloat {
        guard isScrollableStep, keyboardHeight > 0 else { return 0 }
        return max(0, keyboardHeight - footerPinnedHeight + 24)
    }
    private func keyboardDismissBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardHeight > 0 else { return footerPinnedHeight + 8 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - keyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + keyboardFloatingGap
    }
    private var introHeroHeight: CGFloat {
        switch screenHeight {
        case ...680: return 210
        case ...740: return 240
        case ...812: return 300
        default: return 420
        }
    }
    private var introFooterReserve: CGFloat {
        screenHeight <= 680 ? 122 : (screenHeight <= 740 ? 112 : 92)
    }

    private func categoryKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }
        let andNormalized = trimmed.replacingOccurrences(of: "&", with: " and ")
        let cleaned = andNormalized.replacingOccurrences(
            of: "[^a-z0-9]+",
            with: " ",
            options: .regularExpression
        )
        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    @ViewBuilder
    private var mainContentContainer: some View {
        if isScrollableStep {
            ScrollViewReader { proxy in
                ScrollView(currentScrollAxes) {
                    mainContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .onChange(of: focusedField) { _, newValue in
                    guard step == .createCategories, newValue == .category, keyboardHeight > 0 else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(createCategoriesCustomCategoryScrollID, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: keyboardHeight) { _, newValue in
                    guard
                        step == .createCategories,
                        addingCategory,
                        focusedField == .category,
                        newValue > 0,
                        shouldScrollCreateCategoriesToInputAfterKeyboard
                    else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(createCategoriesCustomCategoryScrollID, anchor: .bottom)
                        }
                        shouldScrollCreateCategoriesToInputAfterKeyboard = false
                    }
                }
            }
        } else {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var bottomInsetContent: some View {
        if step != .intro && !isLifeOSInsightsMode {
            VStack(spacing: 6) {
                if step == .createCategories, shouldShowRefreshButton {
                    Button("refresh") {
                        restoreDeletedDefaultCategories()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                footer
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private var introFooterOverlay: some View {
        if step == .intro {
            footer
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(Color(.systemGroupedBackground))
                .zIndex(20)
        }
    }

    private var baseBodyContent: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            mainContentContainer
        }
    }

    private var bodyLayout: some View {
        baseBodyContent
            .safeAreaInset(edge: .bottom) {
                bottomInsetContent
            }
            .overlay(alignment: .bottom) {
                introFooterOverlay
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle(currentStepDisplayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isLifeOSInsightsMode ? false : (step != .intro))
            .toolbar {
                if step != .intro && !isLifeOSInsightsMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            goBack()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
            }
    }

    private var bodyLifecycle: some View {
        bodyLayout
            .onAppear { handleBodyAppear() }
            .onDisappear { handleBodyDisappear() }
    }

    private var bodyDraftPersistenceObservers: some View {
        bodyLifecycle
            .onChange(of: step) { _, _ in persistDraftIfNeeded() }
            .onChange(of: visionIndex) { _, _ in persistDraftIfNeeded() }
            .onChange(of: purposeIndex) { _, _ in persistDraftIfNeeded() }
            .onChange(of: deepIndex) { _, _ in persistDraftIfNeeded() }
            .onChange(of: selectedCategoryNames) { _, _ in persistDraftIfNeeded() }
            .onChange(of: customCategoryNames) { _, _ in persistDraftIfNeeded() }
            .onChange(of: deletedDefaultCategoryNames) { _, _ in persistDraftIfNeeded() }
            .onChange(of: categoryColorKeys) { _, _ in persistDraftIfNeeded() }
            .onChange(of: priorityCategoryIDs) { _, _ in persistDraftIfNeeded() }
            .onChange(of: visionDrafts) { _, _ in persistDraftIfNeeded() }
            .onChange(of: purposeDrafts) { _, _ in persistDraftIfNeeded() }
    }

    private var bodyFinal: some View {
        bodyDraftPersistenceObservers
            .overlay(alignment: .bottom) {
                validationHintOverlay
            }
            .onChange(of: step) { _, newValue in
                handleStepFocusChange(newValue)
                handleAutoStartForStep(newValue)
            }
            .onChange(of: purposeIndex) { _, _ in
                if step == .purposeSweep {
                    handleAutoStartForStep(step)
                }
            }
            .onChange(of: roleIndex) { _, _ in
                if step == .roles {
                    handleAutoStartForStep(step)
                }
            }
            .onChange(of: deepIndex) { _, _ in
                if step == .littleWins {
                    handleAutoStartForStep(step)
                }
            }
            .onChange(of: isGeneratingFulfillmentInsights, initial: false) { _, newValue in
                setAutoWriteLoadingAnimation(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                handleKeyboardFrameChange(note)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
            .overlay {
                keyboardAccessoryOverlay
            }
    }

    var body: some View {
        bodyFinal
    }

    @ViewBuilder
    private var validationHintOverlay: some View {
        let persistentColorConflict = step == .createCategories && (hasCreateCategoriesColorConflict || hasAddSingleAreaActiveColorConflict)
        if persistentColorConflict || showValidationHint {
            Text(persistentColorConflict ? "Each color can only be used once." : validationHintText)
                .font(.footnote)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 56)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var keyboardAccessoryOverlay: some View {
        GeometryReader { proxy in
            if isKeyboardVisible || shouldShowMissionAutoWriteControls || shouldShowIdentityAutoWriteControls || shouldShowLittleWinAutoWriteControls {
                HStack(spacing: 8) {
                    if shouldShowMissionAutoWriteControls {
                        missionAutoWriteControls
                    } else if shouldShowIdentityAutoWriteControls {
                        identityAutoWriteControls
                    } else if shouldShowLittleWinAutoWriteControls {
                        littleWinAutoWriteControls
                    }
                    if isKeyboardVisible {
                        keyboardDismissButton
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, keyboardDismissBottomPadding(in: proxy))
            }
        }
    }

    private func handleBodyAppear() {
        guard !didInitializeViewState else { return }
        didInitializeViewState = true
        previousAutosaveEnabled = modelContext.autosaveEnabled
        // Always stage onboarding edits in draft storage/context only.
        // Nothing should be committed to shared app data until Summary -> Continue.
        usesDraftPersistence = true
        modelContext.autosaveEnabled = false
        if isLifeOSInsightsMode {
            usesDraftPersistence = false
            loadFromPersistentData()
            step = .insights
        } else if isAddSingleAreaMode {
            usesDraftPersistence = false
            step = .createCategories
            loadFromPersistentData()
            applyLoomAIPrefillIfAvailable()
        } else if !restoreDraftIfAvailable() {
            loadFromPersistentData()
        }
        handleAutoStartForStep(step)
    }

    private func handleBodyDisappear() {
        autoWriteIconAnimationTask?.cancel()
        autoWriteIconAnimationTask = nil
        if usesDraftPersistence && !didFinalizeOnboarding {
            persistDraft()
        }
        if usesDraftPersistence && !didFinalizeOnboarding {
            modelContext.rollback()
        }
        modelContext.autosaveEnabled = previousAutosaveEnabled
    }

    private func handleStepFocusChange(_ newValue: Step) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            _ = newValue
            focusedField = nil
        }
    }

    private func handleKeyboardFrameChange(_ note: Notification) {
        guard
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }
        let screenHeight = UIScreen.main.bounds.height
        let overlap = max(0, screenHeight - frame.minY)
        keyboardHeight = overlap
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            switch step {
            case .intro:
                introStep
            case .createCategories:
                createCategoriesStep
            case .visionSweep:
                purposeSweepStep
            case .purposeSweep:
                purposeSweepStep
            case .priorities:
                prioritiesStep
            case .roles:
                rolesStep
            case .littleWins:
                littleWinsStep
            case .resources:
                passionsStep
            case .passions:
                passionsStep
            case .summary:
                summaryStep
            case .insights:
                insightsStep
            }
        }
        .padding(.horizontal)
        .padding(.bottom, (step == .intro ? introFooterReserve : (step == .summary ? 100 : 0)) + keyboardScrollableBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var keyboardDismissButton: some View {
        Button {
            handleKeyboardAccessoryTap()
        } label: {
            Image(systemName: keyboardDismissShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(keyboardDismissShowsCheckmark ? .white : .primary.opacity(0.85))
                .frame(width: 45, height: 45)
                .background(
                    Group {
                        if keyboardDismissShowsCheckmark {
                            Circle().fill(Color.blue)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(
                            keyboardDismissShowsCheckmark
                            ? Color.blue.opacity(0.9)
                            : Color.white.opacity(0.28),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var keyboardDismissShowsCheckmark: Bool {
        switch step {
        case .createCategories:
            return addingCategory && !newCategoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .visionSweep:
            return !currentMissionVisionTextTrimmed.isEmpty
        case .purposeSweep:
            return !currentMissionPurposeTextTrimmed.isEmpty
        case .roles:
            return addingRole && !roleEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .littleWins:
            return addingFocus && !focusEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    private var currentMissionVisionTextTrimmed: String {
        guard let record = currentVisionRecord else { return "" }
        return (visionDrafts[record.category_id] ?? record.category_vision)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentMissionPurposeTextTrimmed: String {
        guard let record = currentPurposeRecord else { return "" }
        return (purposeDrafts[record.category_id] ?? record.category_purpose)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleKeyboardAccessoryTap() {
        if step == .visionSweep, keyboardDismissShowsCheckmark {
            highlightInvalid = false
            invalidCategoryIDs = []
            showValidationHint = false
            focusedField = nil
            advanceFromCurrentStep()
            return
        }

        if step == .purposeSweep, keyboardDismissShowsCheckmark {
            highlightInvalid = false
            invalidCategoryIDs = []
            showValidationHint = false
            focusedField = nil
            advanceFromCurrentStep()
            return
        }

        if step == .roles, keyboardDismissShowsCheckmark, let record = currentRoleRecord {
            commitRole(record)
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
            return
        }

        if step == .littleWins, keyboardDismissShowsCheckmark, let record = currentDeepRecord {
            commitFocus(record)
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
            return
        }

        dismissKeyboard()
    }

    private func dismissKeyboard() {
        commitKeyboardEntryIfNeeded()
        focusedField = nil
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func commitKeyboardEntryIfNeeded() {
        if addingCategory {
            let trimmed = newCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                addingCategory = false
                newCategoryText = ""
            } else {
                addCategory()
            }
            return
        }

        if addingRole {
            if let record = currentRoleRecord {
                commitRole(record)
            } else {
                addingRole = false
                roleEntry = ""
                focusedField = nil
            }
            return
        }

        if addingFocus {
            if let record = currentDeepRecord {
                commitFocus(record)
            } else {
                addingFocus = false
                focusEntry = ""
                focusedField = nil
            }
            return
        }

        if addingResource {
            if let record = currentDeepRecord {
                commitResource(record)
            } else {
                addingResource = false
                resourceEntry = ""
                focusedField = nil
            }
            return
        }
    }

    private var header: some View {
        VStack(spacing: 1) {
            if step == .intro {
                ZStack {
                    FulfillmentIntroRouteLinesView()
                        .padding(.horizontal, -24)
                        .allowsHitTesting(false)
                    if let image = UIImage(named: "FulfillmentGraphic") {
                        Image(uiImage: image)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: introHeroHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .frame(height: introHeroHeight)
                .padding(.bottom, 2)
            }

            if step != .intro && showsProgressStrip {
                progressStrip
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if step == .intro {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(isCompactIntroLayout ? .caption2 : .caption)
                    Text("~7 minutes")
                        .font((isCompactIntroLayout ? Font.caption2 : .caption).weight(.bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, isCompactIntroLayout ? 8 : 10)
                .padding(.vertical, isCompactIntroLayout ? 4 : 6)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
            }

        }
    }

    private var currentStepDisplayTitle: String {
        if isAddSingleAreaMode && step == .createCategories {
            return "Add Fulfillment Area"
        }
        return step.title
    }

    private var progressStrip: some View {
        HStack(spacing: 6) {
            ForEach(1...progressTotalSteps, id: \.self) { index in
                progressSegment(for: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.easeInOut(duration: 0.22), value: progressCurrentStep)
        .animation(.easeInOut(duration: 0.22), value: nestedProgressFraction ?? 0)
        .animation(.easeInOut(duration: 0.22), value: nestedProgressFraction != nil)
    }

    private func progressSegment(for index: Int) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(primarySegmentColor(for: index))

            if index == progressCurrentStep, let nested = nestedProgressFraction {
                GeometryReader { geo in
                    let clamped = max(0.0, min(1.0, nested))
                    let available = max(geo.size.width, 0)
                    let fillWidth = max(available * clamped, 0)
                    Capsule()
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.82 : 0.75))
                        .frame(width: fillWidth, height: geo.size.height)
                        .position(
                            x: fillWidth / 2,
                            y: geo.size.height / 2
                        )
                        .opacity(0.9)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .frame(width: 26)
        .frame(height: 4)
    }

    private func primarySegmentColor(for index: Int) -> Color {
        if index < progressCurrentStep {
            return .accentColor
        }
        if index == progressCurrentStep {
            // Keep active multi-page step neutral until fully completed.
            return (nestedProgressFraction != nil) ? Color(.systemGray4) : .accentColor
        }
        return Color(.systemGray4)
    }

    private var nestedProgressFraction: CGFloat? {
        switch step {
        case .visionSweep:
            let total = orderedFulfillments.count
            guard total > 1 else { return nil }
            return CGFloat(visionIndex + 1) / CGFloat(total)
        case .purposeSweep:
            let total = orderedFulfillments.count
            guard total > 1 else { return nil }
            return CGFloat(purposeIndex + 1) / CGFloat(total)
        case .roles:
            let total = roleCategoryIDs.count
            guard total > 1 else { return nil }
            return CGFloat(roleIndex + 1) / CGFloat(total)
        case .littleWins:
            let total = deepCategoryIDs.count
            guard total > 1 else { return nil }
            return CGFloat(deepIndex + 1) / CGFloat(total)
        case .passions:
            let total = roleCategoryIDs.count
            guard total > 1 else { return nil }
            return CGFloat(passionIndex + 1) / CGFloat(total)
        default:
            return nil
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step == .intro {
                Button {
                    ignoreBackUntil = Date().addingTimeInterval(0.45)
                    step = .createCategories
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            } else if step == .summary {
                Button {
                    guard summaryCanComplete else {
                        triggerHint("Please complete required setup items.")
                        return
                    }
                    step = .insights
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!summaryCanComplete)
            } else if step == .insights {
                Button {
                    finalizeAndContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            } else {
                Button {
                    if shouldForceColorPickerBeforeProceed {
                        guard let category = selectedCategoryNames.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                              !category.isEmpty else {
                            triggerValidationFeedback()
                            return
                        }
                        isForcedColorPickerForProceed = true
                        colorPickerCategory = category
                        showColorPicker = true
                    } else if isNextDisabled {
                        triggerValidationFeedback()
                    } else {
                        highlightInvalid = false
                        invalidCategoryIDs = []
                        showValidationHint = false
                        advanceFromCurrentStep()
                    }
                } label: {
                    Text(footerPrimaryButtonTitle)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(isNextDisabled ? Color(.systemGray3) : .accentColor)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .contentShape(Rectangle())
    }

    private var footerPrimaryButtonTitle: String {
        if isAddSingleAreaMode && step == .passions {
            return "Completed"
        }
        if isAddSingleAreaMode && step == .littleWins,
           let record = currentDeepRecord,
           getFoci(for: record).isEmpty {
            return "Skip"
        }
        return "Next"
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: isCompactIntroLayout ? 8 : 10) {
            Text("Design the most important areas of your life.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
            Text("These are core categories that drive fulfillment. When they're out of balance, life is harder.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
            Text("They're never finished. You continually improve them to stay moving forward.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(isCompactIntroLayout ? 12 : 14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var createCategoriesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.7))
                    .padding(.top, 1)
                Text("Fulfillment areas can be revised anytime.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.black.opacity(0.7))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
            )

            Text(isAddSingleAreaMode
                 ? "What area of your life must you consistently improve to succeed?"
                 : "What 3-7 areas of your life must you consistently improve to succeed?")
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            List {
                ForEach(availableCategoryNames, id: \.self) { category in
                    let selected = selectedCategoryNames.contains(category)
                    let isActiveExisting = isAddSingleAreaMode && existingActiveCategoryKeys.contains(categoryKey(category))
                    let isConflicting = conflictingSelectedCategories.contains(category)
                    let hasSingleAreaActiveColorConflictForRow =
                        isAddSingleAreaMode &&
                        selected &&
                        hasAddSingleAreaActiveColorConflict
                    let shouldHighlightColorCircleConflict =
                        isConflicting || hasSingleAreaActiveColorConflictForRow
                    HStack(spacing: 8) {
                        Button {
                            guard !isActiveExisting else { return }
                            isForcedColorPickerForProceed = false
                            colorPickerCategory = category
                            showColorPicker = true
                        } label: {
                            Circle()
                                .fill(fulfillmentCategoryColor(for: category))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            shouldHighlightColorCircleConflict ? Color.red : Color(.systemGray4),
                                            lineWidth: shouldHighlightColorCircleConflict ? 2 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isActiveExisting)

                        Text(category)
                            .font(.system(size: 20))
                            .foregroundStyle(fulfillmentCategoryColor(for: category))
                            .opacity(isActiveExisting ? 0.5 : 1.0)

                        Spacer()
                        if isConflicting {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }

                        Button {
                            guard !isActiveExisting else { return }
                            toggleCategorySelection(category)
                        } label: {
                            Image(systemName: (selected || isActiveExisting) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    isActiveExisting ? Color.secondary.opacity(0.6) :
                                        (selected ? Color.blue : Color.secondary)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isActiveExisting)
                    }
                    .opacity(isActiveExisting ? 0.62 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isActiveExisting else { return }
                        toggleCategorySelection(category)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !isActiveExisting {
                        Button(role: .destructive) {
                            attemptRemoveCategoryFromStepList(category)
                        } label: {
                            Text("Delete")
                        }
                        .tint(.red)
                        }
                    }
                    .listRowBackground(rowSurfaceColor)
                }

                if addingCategory {
                    TextField("Custom Category", text: $newCategoryText)
                        .font(.system(size: 20))
                        .focused($focusedField, equals: .category)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .submitLabel(.done)
                        .onSubmit(addCategory)
                        .listRowBackground(rowSurfaceColor)
                } else {
                    Button("+ Custom Category") {
                        addingCategory = true
                        newCategoryText = ""
                        shouldScrollCreateCategoriesToInputAfterKeyboard = true
                        DispatchQueue.main.async {
                            focusedField = .category
                        }
                    }
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(rowSurfaceColor)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 56)
            .frame(height: createCategoriesListHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .id(createCategoriesCustomCategoryScrollID)

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNeedHelpCategories.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Need help?")
                        Image(systemName: showNeedHelpCategories ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                if showNeedHelpCategories {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fulfillment Areas are the key parts of your life you continually strengthen and maintain.")
                        Text("They are not one-time goals. When these areas are strong, life feels stable and balanced. When neglected, progress in other areas becomes harder.")
                        Text("Every action you take will connect to one of these areas, helping you focus on what truly matters instead of reacting to what feels urgent.")
                        Text("Start simple. You can refine or change them anytime.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showColorPicker) {
            FulfillmentStartColorPickerSheet(
                category: colorPickerCategory,
                currentColorKey: FulfillmentCategoryTheme.colorKey(for: colorPickerCategory, colorKeys: categoryColorKeys),
                options: availableColorOptions(for: colorPickerCategory),
                showsCloseButton: !isForcedColorPickerForProceed,
                onSelect: { colorKey in
                    let shouldProceed = isForcedColorPickerForProceed
                    applyColorSelection(for: colorPickerCategory, colorKey: colorKey)
                    showColorPicker = false
                    isForcedColorPickerForProceed = false
                    if shouldProceed && canAddSingleArea {
                        highlightInvalid = false
                        invalidCategoryIDs = []
                        showValidationHint = false
                        advanceFromCurrentStep()
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showColorPicker) { _, isPresented in
            if !isPresented {
                isForcedColorPickerForProceed = false
            }
        }
    }

    private var visionSweepStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let record = currentVisionRecord {
                let isInvalid = highlightInvalid &&
                    (visionDrafts[record.category_id] ?? record.category_vision)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                categoryHeader(record.category, index: visionIndex + 1, total: orderedFulfillments.count)
                Text("What does your ideal life look like in this area?")
                    .font(.headline)

                multiLineEditor(
                    text: Binding(
                        get: { visionDrafts[record.category_id] ?? record.category_vision },
                        set: { visionDrafts[record.category_id] = $0 }
                    ),
                    placeholder: "Keep it simple and clear...",
                    showError: isInvalid
                )
                .focused($focusedField, equals: .vision)

                visionIdeasExpander
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var purposeSweepStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let record = currentPurposeRecord {
                let isInvalid = highlightInvalid &&
                    (purposeDrafts[record.category_id] ?? record.category_purpose)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                categoryHeader(record.category, index: purposeIndex + 1, total: orderedFulfillments.count)
                Text("Why does improving this area truly matter?")
                    .font(.headline)

                multiLineEditor(
                    text: Binding(
                        get: { purposeDrafts[record.category_id] ?? record.category_purpose },
                        set: { purposeDrafts[record.category_id] = $0 }
                    ),
                    placeholder: "Keep it simple and clear...",
                    showError: isInvalid
                )
                .focused($focusedField, equals: .purpose)

                purposeIdeasExpander
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var prioritiesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which areas would improve your life the most right now?")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(orderedFulfillments, id: \.category_id) { record in
                    let selected = priorityCategoryIDs.contains(record.category_id)
                    Button {
                        togglePriority(record.category_id)
                    } label: {
                        HStack {
                            Text(record.category)
                                .foregroundStyle(fulfillmentCategoryColor(for: record.category))
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(rowSurfaceColor, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    selected
                                        ? Color.blue.opacity(0.6)
                                        : (highlightInvalid && priorityCategoryIDs.isEmpty ? Color.red.opacity(0.85) : Color.clear),
                                    lineWidth: (selected || (highlightInvalid && priorityCategoryIDs.isEmpty)) ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var rolesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentRoleRecord {
                let rolesItems = getRoles(for: record)
                let isInvalid = highlightInvalid && rolesItems.isEmpty
                categoryHeader(record.category, index: roleIndex + 1, total: roleCategoryIDs.count)
                Text("Who do you want to be in this area of your life?")
                    .font(.headline)

                VStack(spacing: 0) {
                    if rolesItems.count < 3 {
                        if addingRole {
                            TextField("Add Identity", text: $roleEntry)
                                .focused($focusedField, equals: .role)
                                .textInputAutocapitalization(.sentences)
                                .autocorrectionDisabled(false)
                                .submitLabel(.done)
                                .onSubmit {
                                    commitRole(record)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .background(isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor)
                        } else {
                            Button {
                                addingRole = true
                                roleEntry = ""
                                focusedField = .role
                            } label: {
                                HStack(spacing: 0) {
                                    Text("+ Add Identity")
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor)
                        }
                    }

                    ForEach(rolesItems, id: \.id) { item in
                        HStack {
                            Text(item.role)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(role: .destructive) {
                                if let idx = rolesItems.firstIndex(where: { $0.id == item.id }) {
                                    deleteRoles(at: IndexSet(integer: idx), record: record)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isInvalid ? Color.red.opacity(0.85) : Color.clear, lineWidth: 1.5)
                )

                VStack(alignment: .leading, spacing: 6) {
                    if isSelectableDefaultCategory(record.category),
                       let suggestions = autoWriteIdentitySuggestionsByCategoryID[record.category_id],
                       !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(suggestions, id: \.id) { suggestion in
                                let isApplied = isIdentitySuggestionApplied(suggestion, for: record)
                                Button {
                                    let didApply = applyIdentityAutoWriteSuggestion(suggestion, for: record)
                                    guard didApply else { return }
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image("LoomAI")
                                            .resizable()
                                            .renderingMode(.template)
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                            .padding(.top, 1)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(
                                                suggestionTopLine(
                                                    suggestion,
                                                    category: record.category,
                                                    isApplied: isApplied,
                                                    showReplaceContext: rolesItems.count >= 3
                                                )
                                            )
                                                .font(.subheadline.italic())
                                                .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
                                                .multilineTextAlignment(.leading)
                                            Text(suggestion.identity)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                                .multilineTextAlignment(.leading)
                                            if rolesItems.count >= 3,
                                               let replacing = suggestion.replaceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines),
                                               !replacing.isEmpty {
                                                Text("\(isApplied ? "Replaced" : "Replacing"): \(replacing)")
                                                    .font(.caption)
                                                    .foregroundStyle(autoWriteSuggestionSecondaryColor(isApplied: isApplied))
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isApplied)
                            }
                        }
                    }

                    if isSelectableDefaultCategory(record.category),
                       let error = autoWriteIdentityErrorByCategoryID[record.category_id] {
                        fulfillmentRetryRow(
                            message: error,
                            troubleshooting: autoWriteIdentityTroubleshootingByCategoryID[record.category_id],
                            buttonTitle: "Try again"
                        ) {
                            Task { await requestAutoWriteIdentitySuggestions(for: record, forceRefresh: true) }
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNeedIdeasRoles.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Need help?")
                            Image(systemName: showNeedIdeasRoles ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    if showNeedIdeasRoles {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Roles define your identity.")
                                .fontWeight(.bold)
                            Text("They guide how you think, act, and make decisions before results show up. Instead of focusing only on goals, focus on the person who naturally creates those outcomes.")
                            Text("Choose identities that feel empowering and motivating. These should reflect the best version of yourself in this area.")
                            Text("You can update these anytime as you evolve.")
                            Text("Examples:")
                                .fontWeight(.bold)
                            Text("• Athlete").italic()
                            Text("• Wealth Builder").italic()
                            Text("• Focused Student").italic()
                            Text("• Loving Partner").italic()
                            Text("• Empowering Leader").italic()
                            Text("• Energized Creator").italic()
                            Text("• Community Contributor").italic()
                            Text("• Prayer Warrior").italic()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var littleWinsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentDeepRecord {
                littleWinsContent(for: record)
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .sheet(
            isPresented: $isPresentingLittleWinsAdvancedSheet,
            onDismiss: handleLittleWinsAdvancedSheetDismiss
        ) {
            if let categoryID = littleWinsAdvancedCategoryID {
                let categoryTitle = orderedFulfillments.first(where: { $0.category_id == categoryID })?.category ?? "Fulfillment Area"
                LittleWinsManagerSheetView(
                    categoryID: categoryID,
                    categoryTitle: categoryTitle,
                    showsAddButton: false,
                    persistsChanges: false
                )
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func littleWinsContent(for record: Fulfillment) -> some View {
        let fociItems = getFoci(for: record)
        let isInvalid = highlightInvalid && fociItems.isEmpty
        let rowBackground = isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor

        categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
        Text("What small, repeatable wins can move this area forward?")
            .font(.headline)

        VStack(spacing: 0) {
            if addingFocus, fociItems.count < 3 {
                TextField("Add Little Win", text: $focusEntry)
                    .focused($focusedField, equals: .focus)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.done)
                    .onSubmit { commitFocus(record) }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(rowBackground)
            } else if fociItems.count < 3 {
                Button {
                    addingFocus = true
                    focusEntry = ""
                    focusedField = .focus
                } label: {
                    HStack(spacing: 0) {
                        Text("+ Add Little Win")
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background(rowBackground)
            }

            ForEach(fociItems, id: \.id) { item in
                HStack(spacing: 8) {
                    if isAppleHealthIntegrationFriendlyLittleWin(item.activity, category: record.category) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                    Text(item.activity)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(role: .destructive) {
                        if let idx = fociItems.firstIndex(where: { $0.id == item.id }) {
                            deleteFoci(at: IndexSet(integer: idx), record: record)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background(rowBackground)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isInvalid ? Color.red.opacity(0.85) : Color.clear, lineWidth: 1.5)
        )

        if isHealthEnergyCategory(record.category) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .padding(.top, 1)
                Text("Apple Health: integration-friendly Little Wins that can be set to automatically verify in \"Advanced\", no manual completion if set up.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        VStack(alignment: .leading, spacing: 6) {
            if isSelectableDefaultCategory(record.category),
               let suggestions = autoWriteLittleWinSuggestionsByCategoryID[record.category_id],
               !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions, id: \.id) { suggestion in
                        let isApplied = isLittleWinSuggestionApplied(suggestion, for: record)
                        Button {
                            let didApply = applyLittleWinAutoWriteSuggestion(suggestion, for: record)
                            guard didApply else { return }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image("LoomAI")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                    .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(
                                        littleWinSuggestionTopLine(
                                            suggestion,
                                            category: record.category,
                                            isApplied: isApplied,
                                            showReplaceContext: fociItems.count >= 3
                                        )
                                    )
                                        .font(.subheadline.italic())
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
                                        .multilineTextAlignment(.leading)
                                    HStack(alignment: .top, spacing: 6) {
                                        if isAppleHealthIntegrationFriendlyLittleWin(suggestion.activity, category: record.category) {
                                            Image(systemName: "heart.fill")
                                                .foregroundStyle(.red)
                                                .padding(.top, 1)
                                        }
                                        Text(suggestion.activity)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                            .multilineTextAlignment(.leading)
                                    }
                                    if fociItems.count >= 3,
                                       let replacing = suggestion.replaceActivity?.trimmingCharacters(in: .whitespacesAndNewlines),
                                       !replacing.isEmpty {
                                        Text("\(isApplied ? "Replaced" : "Replacing"): \(replacing)")
                                            .font(.caption)
                                            .foregroundStyle(autoWriteSuggestionSecondaryColor(isApplied: isApplied))
                                            .multilineTextAlignment(.leading)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isApplied)
                    }
                }
            }

            if isSelectableDefaultCategory(record.category),
               let error = autoWriteLittleWinErrorByCategoryID[record.category_id] {
                fulfillmentRetryRow(
                    message: error,
                    troubleshooting: autoWriteLittleWinTroubleshootingByCategoryID[record.category_id],
                    buttonTitle: "Try again"
                ) {
                    Task { await requestAutoWriteLittleWinSuggestions(for: record, forceRefresh: true) }
                }
            }

            if !fociItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    VStack(spacing: 0) {
                        Button {
                            presentLittleWinsAdvancedSheet(for: record)
                        } label: {
                            HStack {
                                Text("Advanced")
                                    .font(.body.weight(.regular))
                                    .foregroundStyle(.blue)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(rowSurfaceColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("Schedule Little Wins for certain week days and integrate with Apple Health (examples: 10,000 steps, 60 min workout)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNeedIdeasLittleWins.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Need Help?")
                    Image(systemName: showNeedIdeasLittleWins ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showNeedIdeasLittleWins {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Small actions create momentum.")
                        .fontWeight(.bold)
                    Text("Focus on a few easy, high-impact 1-3 actions you can do consistently.")
                    Text("These should be simple enough that you can follow through even on busy or low-energy days.")
                    Text("Examples:")
                        .fontWeight(.bold)
                    Text("• Stretch or walk").italic()
                    Text("• Pray or journal").italic()
                    Text("• Review budget").italic()
                    Text("• Call loved one").italic()
                    Text("• Read for 10 min").italic()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var resourcesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentDeepRecord {
                let resourcesItems = getResources(for: record)
                let isInvalid = highlightInvalid && resourcesItems.isEmpty
                let rowBackground = isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor

                categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
                Text("What people, tools, or environments can help you improve this area?")
                    .font(.headline)

                VStack(spacing: 0) {
                    if addingResource, resourcesItems.count < 3 {
                        TextField("Add Resource", text: $resourceEntry)
                            .focused($focusedField, equals: .resource)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                            .submitLabel(.done)
                            .onSubmit {
                                commitResource(record)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(rowBackground)
                    } else if resourcesItems.count < 3 {
                        Button("+ Add Resource") {
                            addingResource = true
                            resourceEntry = ""
                            focusedField = .resource
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(rowBackground)
                    }

                    ForEach(resourcesItems, id: \.id) { item in
                        HStack {
                            Text(item.resource)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(role: .destructive) {
                                if let idx = resourcesItems.firstIndex(where: { $0.id == item.id }) {
                                    deleteResources(at: IndexSet(integer: idx), record: record)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(rowBackground)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isInvalid ? Color.red.opacity(0.85) : Color.clear, lineWidth: 1.5)
                )

                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNeedIdeasResources.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Need Help?")
                            Image(systemName: showNeedIdeasResources ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    if showNeedIdeasResources {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Strong support makes success easier.")
                                .fontWeight(.bold)
                            Text("Focus on 1–3 people, tools, or environments that support consistent growth.")
                            Text("Choose resources that reduce friction and make the right behavior more automatic.")
                            Text("Examples:")
                                .fontWeight(.bold)
                            Text("• Great gym").italic()
                            Text("• Accountability partner").italic()
                            Text("• Mentor or coach").italic()
                            Text("• Budgeting app").italic()
                            Text("• Supportive community").italic()
                            Text("• Quiet workspace").italic()
                            Text("• State park nearby").italic()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var passionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentPassionRecord {
                categoryHeader(record.category, index: passionIndex + 1, total: roleCategoryIDs.count)
                Text("What passions drive you to improve this area?")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(passions, id: \.passion_id) { passion in
                        let isSelected = selectedPassionIDs(for: record.category_id).contains(passion.passion_id)
                        let selectionCount = passionSelectionCount(for: passion.passion_id)
                        Button {
                            togglePassion(passion, for: record.category_id)
                        } label: {
                            HStack {
                                Text("\(displayEmotionLabel(for: passion.emotion)): \(passion.passion)")
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Text("\(selectionCount)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? .blue : .secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(
                                highlightInvalid && selectedPassions(for: record.category_id).isEmpty ? Color.red.opacity(0.08) : rowSurfaceColor
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(highlightInvalid && selectedPassions(for: record.category_id).isEmpty ? Color.red.opacity(0.85) : Color.clear, lineWidth: 1.5)
                )
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            summarySection(title: "Categories (* Increased Focus)") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(orderedFulfillments, id: \.category_id) { record in
                        let isFocus = priorityCategoryIDs.contains(record.category_id)
                        Text(isFocus ? "\(record.category) *" : record.category)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(fulfillmentCategoryColor(for: record.category))
                    }
                }
            } onEdit: {
                step = .createCategories
            }

            summarySection(title: "Increased Focus Areas") {
                let focused = orderedFulfillments.filter { priorityCategoryIDs.contains($0.category_id) }
                if focused.isEmpty {
                    Text("None selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(focused, id: \.category_id) { record in
                            categoryDetailsBlock(
                                record: record,
                                includeVisionPurpose: false,
                                markAsFocus: true,
                                includeLittleWinsResources: true,
                                includePassions: false
                            )
                        }
                    }
                }
            } onEdit: {
                step = .priorities
            }

            summarySection(title: "All") {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isAllSummaryExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Spacer(minLength: 0)
                            Text(isAllSummaryExpanded ? "Hide" : "Show")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                            Image(systemName: isAllSummaryExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)

                    if isAllSummaryExpanded {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(orderedFulfillments, id: \.category_id) { record in
                                categoryDetailsBlock(
                                    record: record,
                                    includeVisionPurpose: true,
                                    markAsFocus: false,
                                    includeLittleWinsResources: false,
                                    includePassions: true
                                )
                            }
                        }
                    }
                }
            } onEdit: {
                step = .roles
                deepIndex = 0
            }
        }
    }

    private var insightsStep: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(alignment: .leading, spacing: lifeOSInsightsVerticalSpacing) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PURPOSE")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .tracking(0.45)

                        Text("Your passions reveal who you are and what drives you.")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 16) {
                        ForEach(lifeOSPassionCircleModels, id: \.emotionKey) { item in
                            lifeOSPassionCircle(item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .anchorPreference(
                        key: LifeOSInsightsBoundsPreferenceKey.self,
                        value: .bounds
                    ) { [.purposeCircles: $0] }

                    Color.clear.frame(height: 48)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: lifeOSInsightsVerticalSpacing) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FULFILLMENT")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .tracking(0.45)

                        Text("These areas makeup your life.")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    lifeOSFulfillmentLayeredCluster
                        .anchorPreference(
                            key: LifeOSInsightsBoundsPreferenceKey.self,
                            value: .bounds
                        ) { [.fulfillmentCluster: $0] }
                        .zIndex(10)
                }
                .padding(.vertical, lifeOSInsightsVerticalSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .center)
                .zIndex(10)

                VStack(alignment: .leading, spacing: lifeOSInsightsVerticalSpacing) {
                    Spacer(minLength: 0)
                    lifeOSBottomSystemsGroup(containerHeight: max(250, proxy.size.height * 0.34))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, proxy.safeAreaInsets.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 2)
            .overlayPreferenceValue(LifeOSInsightsBoundsPreferenceKey.self) { anchors in
                GeometryReader { overlayProxy in
                    if
                        let purposeAnchor = anchors[.purposeCircles],
                        let fulfillmentAnchor = anchors[.fulfillmentCluster],
                        let systemsAnchor = anchors[.systemsIcons]
                    {
                        lifeOSInsightsGlobalConnectorLayer(
                            purposeFrame: overlayProxy[purposeAnchor],
                            fulfillmentFrame: overlayProxy[fulfillmentAnchor],
                            systemsFrame: overlayProxy[systemsAnchor]
                        )
                    }
                }
            }
        }
    }

    private func lifeOSBottomSystemsGroup(containerHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: lifeOSInsightsVerticalSpacing) {
            Spacer(minLength: 0)

            lifeOSSystemsConnectorCluster

            Text("These all live inside of each Fulfillment Area. Activity and progress gradually increases your Fulfillment over time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

            if !openedFromPersonalization {
                Text("This page is viewable anytime in Account > Personalization")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                (
                    Text("Estimating Fulfilllment:").bold() +
                    Text(" 3.0 out of 5 is your starting baseline score. As Loom observes your goals, actions, and progress, it estimates fulfillment across each area each week.")
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, minHeight: containerHeight, alignment: .bottom)
    }

    private func lifeOSInsightsGlobalConnectorLayer(
        purposeFrame: CGRect,
        fulfillmentFrame: CGRect,
        systemsFrame: CGRect
    ) -> some View {
        let radarCenter = lifeOSGlobalRadarCenter(for: fulfillmentFrame)
        let purposeStart = CGPoint(x: purposeFrame.midX, y: purposeFrame.maxY + 6)
        let purposeColor = lifeOSRandomConnectorColor(
            start: purposeStart,
            end: radarCenter,
            fallback: .secondary
        )
        let iconCenters = lifeOSIconCenters(for: systemsFrame.width).map { systemsFrame.minX + $0 }
        let connectorColorsByIcon = lifeOSConnectorColorsByIcon
        let targetsByIcon = lifeOSGlobalTargetsByIcon(
            iconCenters: iconCenters,
            connectorColorsByIcon: connectorColorsByIcon,
            width: systemsFrame.width,
            startY: systemsFrame.minY + 6
        )
        let connectorSegments = lifeOSConnectorSegments(
            origin: radarCenter,
            connectorColorsByIcon: connectorColorsByIcon,
            targetsByIcon: targetsByIcon
        )

        return ZStack {
            lifeOSCurvedConnectorLine(
                start: purposeStart,
                end: radarCenter,
                movingColor: purposeColor,
                curveLift: max(0, abs(radarCenter.y - purposeStart.y) * 0.12)
            )

            ForEach(connectorSegments) { segment in
                lifeOSCurvedConnectorLine(
                    start: segment.start,
                    end: segment.end,
                    movingColor: segment.color,
                    curveLift: segment.curveLift,
                    middleHorizontalBend: segment.middleHorizontalBend
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .zIndex(-50)
        .overlay(alignment: .topLeading) {
            lifeOSFulfillmentRadarOcclusionMask
                .frame(width: fulfillmentFrame.width, height: fulfillmentFrame.height, alignment: .top)
                .offset(x: fulfillmentFrame.minX, y: fulfillmentFrame.minY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private func lifeOSGlobalRadarCenter(for fulfillmentFrame: CGRect) -> CGPoint {
        let leftWidth = min(max(fulfillmentFrame.width * 0.43, 128), 220)
        let rightWidth = max(150, fulfillmentFrame.width - leftWidth)
        let radarSize = min(max(186, rightWidth - 8), fulfillmentFrame.height - 8)
        return CGPoint(
            x: fulfillmentFrame.minX + leftWidth + (rightWidth / 2),
            y: fulfillmentFrame.minY + (radarSize / 2)
        )
    }

    private func lifeOSGlobalTargetsByIcon(
        iconCenters: [CGFloat],
        connectorColorsByIcon: [[Color]],
        width: CGFloat,
        startY: CGFloat
    ) -> [[CGPoint]] {
        let originBandWidth = min(max((width / 3) * 0.16, 14), 31)
        return zip(iconCenters, connectorColorsByIcon).map { centerX, colors in
            let lineCount = max(1, colors.count)
            guard lineCount > 1 else {
                return [CGPoint(x: centerX, y: startY)]
            }
            return (0..<lineCount).map { idx in
                let t = CGFloat(idx) / CGFloat(max(lineCount - 1, 1))
                let x = centerX - (originBandWidth / 2) + (originBandWidth * t)
                return CGPoint(x: x, y: startY)
            }
        }
    }

    private enum LifeOSInsightsAnchorID: Hashable {
        case purposeCircles
        case fulfillmentCluster
        case systemsIcons
    }

    private struct LifeOSInsightsBoundsPreferenceKey: PreferenceKey {
        static var defaultValue: [LifeOSInsightsAnchorID: Anchor<CGRect>] = [:]

        static func reduce(
            value: inout [LifeOSInsightsAnchorID: Anchor<CGRect>],
            nextValue: () -> [LifeOSInsightsAnchorID: Anchor<CGRect>]
        ) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
    }

    private struct LifeOSPassionCircleModel: Hashable {
        let iconName: String
        let label: String
        let emotionKey: String
        let value: Int
    }

    private var lifeOSRadarClusterHeight: CGFloat {
        let chipHeight: CGFloat = 30
        let chipSpacing: CGFloat = 8
        let count = max(1, lifeOSFulfillmentRadarMetrics.count)
        let chipStackHeight = (CGFloat(count) * chipHeight) + (CGFloat(max(0, count - 1)) * chipSpacing)
        return max(206, chipStackHeight + 14)
    }
    private var lifeOSInsightsVerticalSpacing: CGFloat { 12 }

    private var lifeOSPassionCircleModels: [LifeOSPassionCircleModel] {
        [
            .init(iconName: "heart.fill", label: "love", emotionKey: "love", value: lifeOSPassionValue(for: "love")),
            .init(iconName: "lock.fill", label: "vows", emotionKey: "vows", value: lifeOSPassionValue(for: "vows")),
            .init(iconName: "bolt.fill", label: "thrill", emotionKey: "thrill", value: lifeOSPassionValue(for: "thrill")),
            .init(iconName: "shield.fill", label: "hate", emotionKey: "just", value: lifeOSPassionValue(for: "just"))
        ]
    }

    private func lifeOSPassionValue(for emotionKey: String) -> Int {
        if let score = lifeOSLatestMonthlyPassionScore(forEmotionKey: emotionKey)
            ?? lifeOSLatestAvailablePassionScore(forEmotionKey: emotionKey) {
            return Int(PassionScoringMath.clamp(score.rounded(), min: 0, max: 4))
        }

        let ids = Set(
            passions
                .filter { $0.emotion == emotionKey }
                .map(\.passion_id)
        )
        let count = draftPassionJoins.filter { ids.contains($0.passionID) }.count
        return min(4, count)
    }

    private func lifeOSLatestMonthlyPassionScore(forEmotionKey emotionKey: String) -> Double? {
        guard let type = lifeOSPassionType(forEmotionKey: emotionKey) else { return nil }
        let monthStart = PassionScoringMath.monthWindow(for: .now).monthStart
        return lifeOSLatestPassionSnapshot(for: type, monthStart: monthStart)?.score
    }

    private func lifeOSLatestAvailablePassionScore(forEmotionKey emotionKey: String) -> Double? {
        guard let type = lifeOSPassionType(forEmotionKey: emotionKey) else { return nil }
        return lifeOSLatestAvailablePassionSnapshot(for: type)?.score
    }

    private func lifeOSLatestPassionSnapshot(for type: PassionType, monthStart: Date) -> PassionScoreSnapshot? {
        passionScoreSnapshots
            .filter {
                $0.passionTypeRaw == type.rawValue &&
                Calendar.current.isDate($0.monthStartDate, inSameDayAs: monthStart)
            }
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    private func lifeOSLatestAvailablePassionSnapshot(for type: PassionType) -> PassionScoreSnapshot? {
        passionScoreSnapshots
            .filter { $0.passionTypeRaw == type.rawValue }
            .max { lhs, rhs in
                let lhsMonth = Calendar.current.startOfDay(for: lhs.monthStartDate)
                let rhsMonth = Calendar.current.startOfDay(for: rhs.monthStartDate)
                if lhsMonth == rhsMonth {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhsMonth < rhsMonth
            }
    }

    private func lifeOSPassionType(forEmotionKey emotionKey: String) -> PassionType? {
        switch emotionKey {
        case "love": return .love
        case "vows": return .vows
        case "thrill": return .thrill
        case "just": return .hate
        default: return nil
        }
    }

    private func lifeOSPassionCircle(_ item: LifeOSPassionCircleModel) -> some View {
        ZStack {
            let gap: Double = 4
            let halfGap = gap / 2
            let radius: CGFloat = 25
            let center = CGPoint(x: radius, y: radius)
            let quadrantAngles: [(start: Double, end: Double)] = [
                (-90, 0), (0, 90), (90, 180), (180, 270)
            ]

            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    let angles = quadrantAngles[index]
                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(angles.start + halfGap),
                            endAngle: .degrees(angles.end - halfGap),
                            clockwise: false
                        )
                    }
                    .stroke((index + 1) <= item.value ? Color.primary : Color(.tertiaryLabel), lineWidth: 2)
                }
            }
            .frame(width: radius * 2, height: radius * 2)

            VStack(spacing: 2) {
                Image(systemName: item.iconName)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(item.label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }

    private func lifeOSVerticalConnectorLine(height: CGFloat) -> some View {
        GeometryReader { proxy in
            let midX = proxy.size.width / 2
            let start = CGPoint(x: midX, y: 0)
            let end = CGPoint(x: midX, y: proxy.size.height)
            let color = lifeOSRandomConnectorColor(start: start, end: end, fallback: .secondary)
            lifeOSRouteLineCanvas(
                start: start,
                end: end,
                colors: [color],
                curveLift: 0,
                lineCount: 1,
                laneSpread: 0
            )
            .zIndex(-200)
        }
        .frame(height: height)
        .zIndex(-200)
    }

    private var lifeOSFulfillmentCategories: [String] {
        var seen = Set<String>()
        let fromRecords = orderedFulfillments
            .map(\.category)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
        if !fromRecords.isEmpty { return fromRecords }

        var fallbackSeen = Set<String>()
        return selectedCategoryNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { fallbackSeen.insert($0.lowercased()).inserted }
    }

    private var lifeOSFulfillmentRadarMetrics: [(String, Color, Double)] {
        let base = lifeOSFulfillmentCategories
        let categories = base.isEmpty ? Array(fulfillmentStartSelectableDefaultCategories.prefix(4)) : base
        return categories.map { category in
            (category, fulfillmentCategoryColor(for: category), 60)
        }
    }

    private var lifeOSConnectorPalette: [Color] {
        let colors = lifeOSFulfillmentRadarMetrics.map(\.1)
        return colors.isEmpty ? [Color.gray.opacity(0.7)] : colors
    }

    private var lifeOSConnectorGradientColors: [Color] {
        let palette = lifeOSConnectorPalette
        return palette.count > 1 ? palette : [palette[0], palette[0]]
    }

    private var lifeOSFulfillmentAreasWithLittleWinsColors: [Color] {
        let colors = orderedFulfillments.compactMap { record -> Color? in
            guard !getFoci(for: record).isEmpty else { return nil }
            return fulfillmentCategoryColor(for: record.category)
        }
        return colors.isEmpty ? [lifeOSLittleWinsAccentColor] : colors
    }

    private var lifeOSLittleWinsAccentColor: Color {
        if let category = orderedFulfillments.first(where: { !getFoci(for: $0).isEmpty })?.category {
            return fulfillmentCategoryColor(for: category)
        }
        return lifeOSFulfillmentRadarMetrics.first?.1 ?? .blue
    }

    private var lifeOSLittleWinsConnectorColors: [Color] {
        Array(lifeOSFulfillmentAreasWithLittleWinsColors.prefix(6).reversed())
    }

    private var lifeOSFulfillmentRadarConnectorLayer: some View {
        GeometryReader { geo in
            let metrics = lifeOSFulfillmentRadarMetrics
            let chipHeight: CGFloat = 30
            let chipSpacing: CGFloat = 8
            let leftWidth = min(max(geo.size.width * 0.43, 128), 220)
            let rightWidth = max(150, geo.size.width - leftWidth)
            let radarSize = min(max(186, rightWidth - 8), geo.size.height - 8)
            let clusterHeight = geo.size.height
            let rowTopInset: CGFloat = 0
            let chipsStartY = rowTopInset
            let radarCenter = CGPoint(x: leftWidth + (rightWidth / 2), y: rowTopInset + (radarSize / 2))
            let indexedMetrics: [LifeOSMetricConnectorInput] = Array(metrics.enumerated()).map {
                LifeOSMetricConnectorInput(id: $0.offset, metric: $0.element)
            }

            ZStack(alignment: .top) {
                ZStack {
                    lifeOSCurvedConnectorLine(
                        start: CGPoint(x: radarCenter.x, y: 4),
                        end: radarCenter,
                        movingColor: Color.secondary.opacity(0.80),
                        curveLift: 0
                    )

                    LifeOSFulfillmentConnectorLines(
                        items: indexedMetrics,
                        chipsStartY: chipsStartY,
                        chipHeight: chipHeight,
                        chipSpacing: chipSpacing,
                        leftWidth: leftWidth,
                        radarCenter: radarCenter,
                        makeConnectorLine: { start, end, color, lift, verticalBend in
                            AnyView(
                                lifeOSCurvedConnectorLine(
                                    start: start,
                                    end: end,
                                    movingColor: color,
                                    curveLift: lift,
                                    middleVerticalBend: verticalBend
                                )
                            )
                        }
                    )
                }
                .allowsHitTesting(false)
                .zIndex(-200)
            }
            .frame(maxWidth: .infinity, minHeight: clusterHeight, maxHeight: clusterHeight, alignment: .top)
        }
    }

    private var lifeOSFulfillmentRadarClusterTopLayer: some View {
        GeometryReader { geo in
            lifeOSFulfillmentRadarForegroundLayout(in: geo, fillStyle: .content)
        }
        .frame(height: lifeOSRadarClusterHeight)
        .allowsHitTesting(false)
        .zIndex(200)
    }

    private var lifeOSFulfillmentLayeredCluster: some View {
        ZStack(alignment: .top) {
            lifeOSFulfillmentRadarConnectorLayer
                .frame(height: lifeOSRadarClusterHeight)
                .overlay(alignment: .top) {
                    lifeOSFulfillmentRadarOcclusionMask
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

            lifeOSFulfillmentRadarClusterTopLayer
        }
    }

    private func lifeOSFulfillmentRadarForeground(
        metrics: [(String, Color, Double)],
        chipHeight: CGFloat,
        chipSpacing: CGFloat,
        leftWidth: CGFloat,
        radarSize: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: chipSpacing) {
                ForEach(metrics, id: \.0) { metric in
                    lifeOSFulfillmentChipRow(
                        title: metric.0,
                        color: metric.1,
                        chipHeight: chipHeight
                    )
                }
            }
            .frame(width: leftWidth, alignment: .leading)
            .zIndex(2)

            FulfillmentInteractiveRadar(
                metrics: metrics,
                selectedIndex: .constant(0),
                onManualSelect: {},
                enableInteraction: false,
                useOriginalDotStyle: true,
                emphasizeSelectedSlice: false
            )
            .frame(width: radarSize, height: radarSize)
            .frame(maxWidth: .infinity, alignment: .center)
            .zIndex(2)
        }
    }

    private func lifeOSFulfillmentChipRow(
        title: String,
        color: Color,
        chipHeight: CGFloat
    ) -> some View {
        lifeOSFulfillmentChipShell(
            chipHeight: chipHeight,
            backgroundColor: color.opacity(0.18),
            strokeColor: color.opacity(0.35)
        ) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func lifeOSFulfillmentChipMaskRow(
        title: String,
        chipHeight: CGFloat
    ) -> some View {
        lifeOSFulfillmentChipShell(
            chipHeight: chipHeight,
            backgroundColor: .black,
            strokeColor: .black
        ) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.clear)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .shadow(color: Color(.systemBackground), radius: 3, x: 0, y: 0)
    }

    private func lifeOSFulfillmentChipShell<Content: View>(
        chipHeight: CGFloat,
        backgroundColor: Color,
        strokeColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, minHeight: chipHeight, alignment: .leading)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
    }

    private var lifeOSFulfillmentRadarOcclusionMask: some View {
        GeometryReader { geo in
            lifeOSFulfillmentRadarForegroundLayout(in: geo, fillStyle: .mask)
        }
        .frame(height: lifeOSRadarClusterHeight)
        .allowsHitTesting(false)
    }

    private enum LifeOSFulfillmentRadarForegroundFillStyle {
        case content
        case mask
    }

    @ViewBuilder
    private func lifeOSFulfillmentRadarForegroundLayout(
        in geo: GeometryProxy,
        fillStyle: LifeOSFulfillmentRadarForegroundFillStyle
    ) -> some View {
        let metrics = lifeOSFulfillmentRadarMetrics
        let chipHeight: CGFloat = 30
        let chipSpacing: CGFloat = 8
        let leftWidth = min(max(geo.size.width * 0.43, 128), 220)
        let rightWidth = max(150, geo.size.width - leftWidth)
        let radarSize = min(max(186, rightWidth - 8), geo.size.height - 8)

        switch fillStyle {
        case .content:
            lifeOSFulfillmentRadarForeground(
                metrics: metrics,
                chipHeight: chipHeight,
                chipSpacing: chipSpacing,
                leftWidth: leftWidth,
                radarSize: radarSize
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .mask:
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: chipSpacing) {
                    ForEach(metrics, id: \.0) { metric in
                        lifeOSFulfillmentChipMaskRow(
                            title: metric.0,
                            chipHeight: chipHeight
                        )
                    }
                }
                .frame(width: leftWidth, alignment: .leading)

                lifeOSFulfillmentRadarSectorMask(metrics: metrics, radarSize: radarSize)
                    .frame(width: radarSize, height: radarSize)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func lifeOSFulfillmentRadarSectorMask(
        metrics: [(String, Color, Double)],
        radarSize: CGFloat
    ) -> some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let half = size / 2
            let radius = half
            let center = CGPoint(x: half, y: half)
            let count = metrics.count
            let dotDiameter: CGFloat = 14

            let outerPoints: [CGPoint] = (0..<count).map { index in
                let angle = Angle.degrees((Double(index) / Double(max(count, 1))) * 360 - 90).radians
                return CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
            }

            let filledPoints: [CGPoint] = outerPoints.enumerated().map { index, point in
                let ratio = max(0.2, min(metrics[index].2 / 100, 1))
                return CGPoint(
                    x: half + (point.x - half) * ratio,
                    y: half + (point.y - half) * ratio
                )
            }

            ZStack {
                if count > 1 {
                    ForEach(0..<count, id: \.self) { index in
                        let nextIndex = (index + 1) % count
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: filledPoints[index])
                            path.addLine(to: filledPoints[nextIndex])
                            path.closeSubpath()
                        }
                        .fill(Color.black)
                    }
                } else if count == 1, let point = filledPoints.first {
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point)
                        path.addArc(
                            center: center,
                            radius: max(2, radius * 0.2),
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270),
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .fill(Color.black)
                }

                ForEach(filledPoints.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.black)
                        .frame(width: dotDiameter, height: dotDiameter)
                        .position(filledPoints[index])
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var lifeOSSystemsConnectorCluster: some View {
        let connectorGap: CGFloat = 8

        return lifeOSSystemsIconsRow
            .frame(maxWidth: .infinity)
            .padding(.top, connectorGap)
            .anchorPreference(
                key: LifeOSInsightsBoundsPreferenceKey.self,
                value: .bounds
            ) { [.systemsIcons: $0] }
            .zIndex(1)
    }

    private var lifeOSSystemsIconsRow: some View {
        HStack(alignment: .bottom, spacing: 26) {
            VStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Goals")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
            .background(Color.clear)

            VStack(spacing: 6) {
                lifeOSLittleWinsMiniCardStack
                Text("Little Wins")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
            .background(Color.clear)

            VStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Action Plans")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
            .background(Color.clear)
        }
    }

    private func lifeOSSystemsConnectorBackground(
        connectorCanvasHeight: CGFloat,
        connectorLift: CGFloat
    ) -> some View {
        GeometryReader { geo in
            let radarCenterX = lifeOSRadarCenterX(for: geo.size)
            let origin = CGPoint(x: radarCenterX, y: 0)
            let connectorColorsByIcon = lifeOSConnectorColorsByIcon
            let iconCenters = lifeOSIconCenters(for: geo.size.width)
            let targetsByIcon = lifeOSTargetsByIcon(
                iconCenters: iconCenters,
                connectorColorsByIcon: connectorColorsByIcon,
                width: geo.size.width,
                connectorCanvasHeight: connectorCanvasHeight
            )
            let connectorSegments = lifeOSConnectorSegments(
                origin: origin,
                connectorColorsByIcon: connectorColorsByIcon,
                targetsByIcon: targetsByIcon
            )

            ZStack {
                ForEach(connectorSegments) { segment in
                    lifeOSCurvedConnectorLine(
                        start: segment.start,
                        end: segment.end,
                        movingColor: segment.color,
                        curveLift: segment.curveLift,
                        middleHorizontalBend: segment.middleHorizontalBend
                    )
                }
            }
            .frame(width: geo.size.width, height: connectorCanvasHeight, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .allowsHitTesting(false)
            .zIndex(-200)
            .background(Color.clear)
        }
        .offset(y: -connectorLift)
        .allowsHitTesting(false)
        .zIndex(-200)
        .background(Color.clear)
    }

    private var lifeOSConnectorColorsByIcon: [[Color]] {
        [
            lifeOSConnectorPalette,
            lifeOSLittleWinsConnectorColors,
            lifeOSConnectorPalette
        ]
    }

    private struct LifeOSConnectorSegment: Identifiable {
        let id: String
        let start: CGPoint
        let end: CGPoint
        let color: Color
        let curveLift: CGFloat
        let middleHorizontalBend: CGFloat
    }

    private struct LifeOSMetricConnectorInput: Identifiable {
        let id: Int
        let metric: (String, Color, Double)
    }

    private struct LifeOSFulfillmentConnectorLines: View {
        let items: [LifeOSMetricConnectorInput]
        let chipsStartY: CGFloat
        let chipHeight: CGFloat
        let chipSpacing: CGFloat
        let leftWidth: CGFloat
        let radarCenter: CGPoint
        let makeConnectorLine: (CGPoint, CGPoint, Color, CGFloat, CGFloat) -> AnyView

        var body: some View {
            items.reduce(AnyView(EmptyView())) { partial, item in
                AnyView(
                    ZStack {
                        partial
                        connectorViews(for: item)
                    }
                )
            }
        }

        @ViewBuilder
        private func connectorViews(for item: LifeOSMetricConnectorInput) -> some View {
            let idx = item.id
            let metric = item.metric
            let chipCenterY = chipsStartY + CGFloat(idx) * (chipHeight + chipSpacing) + (chipHeight / 2)
            let verticalSpread = chipHeight * 0.5
            let centerIndex = CGFloat(max(items.count - 1, 0)) / 2
            let chipOffsetFromCenter = CGFloat(idx) - centerIndex
            let verticalBendMagnitude = abs(radarCenter.y - chipCenterY) * 0.18
            let middleVerticalBend: CGFloat = abs(chipOffsetFromCenter) < 0.01
                ? 0
                : (chipOffsetFromCenter < 0 ? verticalBendMagnitude : -verticalBendMagnitude)

            let topY = chipCenterY - (verticalSpread / 2)
            let middleY = chipCenterY
            let bottomY = chipCenterY + (verticalSpread / 2)

            makeConnectorLine(
                CGPoint(x: leftWidth - 10, y: topY),
                radarCenter,
                metric.1,
                max(0, abs(radarCenter.y - topY) * 0.22),
                middleVerticalBend
            )

            makeConnectorLine(
                CGPoint(x: leftWidth - 10, y: middleY),
                radarCenter,
                metric.1,
                max(0, abs(radarCenter.y - middleY) * 0.22),
                middleVerticalBend
            )

            makeConnectorLine(
                CGPoint(x: leftWidth - 10, y: bottomY),
                radarCenter,
                metric.1,
                max(0, abs(radarCenter.y - bottomY) * 0.22),
                middleVerticalBend
            )
        }
    }

    private func lifeOSRadarCenterX(for size: CGSize) -> CGFloat {
        let leftWidth = min(max(size.width * 0.43, 128), 220)
        let rightWidth = max(150, size.width - leftWidth)
        return leftWidth + (rightWidth / 2)
    }

    private func lifeOSIconCenters(for width: CGFloat) -> [CGFloat] {
        [
            width * 0.16,
            width * 0.50,
            width * 0.84
        ]
    }

    private func lifeOSTargetsByIcon(
        iconCenters: [CGFloat],
        connectorColorsByIcon: [[Color]],
        width: CGFloat,
        connectorCanvasHeight: CGFloat
    ) -> [[CGPoint]] {
        let originBandWidth = min(max((width / 3) * 0.16, 14), 31)
        return zip(iconCenters, connectorColorsByIcon).map { centerX, colors in
            let lineCount = max(1, colors.count)
            guard lineCount > 1 else {
                return [CGPoint(x: centerX, y: connectorCanvasHeight - 2)]
            }
            return (0..<lineCount).map { idx in
                let t = CGFloat(idx) / CGFloat(lineCount - 1)
                let x = centerX - (originBandWidth / 2) + (originBandWidth * t)
                return CGPoint(x: x, y: connectorCanvasHeight - 2)
            }
        }
    }

    private func lifeOSConnectorSegments(
        origin: CGPoint,
        connectorColorsByIcon: [[Color]],
        targetsByIcon: [[CGPoint]]
    ) -> [LifeOSConnectorSegment] {
        var segments: [LifeOSConnectorSegment] = []
        for iconIndex in targetsByIcon.indices {
            let targets = targetsByIcon[iconIndex]
            let colors = connectorColorsByIcon[iconIndex]
            for laneIndex in targets.indices {
                let start = targets[laneIndex]
                let laneLift = 14 + (CGFloat(laneIndex) * 2.2)
                let color = colors[min(laneIndex, max(colors.count - 1, 0))]
                let middleHorizontalBend: CGFloat
                switch iconIndex {
                case 0:
                    middleHorizontalBend = abs(origin.x - start.x) * 0.45
                case 1:
                    middleHorizontalBend = abs(origin.x - start.x) * 0.9
                default:
                    middleHorizontalBend = 0
                }
                segments.append(
                    LifeOSConnectorSegment(
                        id: "\(iconIndex)-\(laneIndex)",
                        start: start,
                        end: origin,
                        color: color,
                        curveLift: laneLift,
                        middleHorizontalBend: middleHorizontalBend
                    )
                )
            }
        }
        return segments
    }

    private func lifeOSCurvedConnectorLine(
        start: CGPoint,
        end: CGPoint,
        movingColor: Color,
        curveLift: CGFloat,
        middleHorizontalBend: CGFloat = 0,
        middleVerticalBend: CGFloat = 0
    ) -> some View {
        return lifeOSRouteLineCanvas(
            start: start,
            end: end,
            colors: [movingColor],
            curveLift: curveLift,
            middleHorizontalBend: middleHorizontalBend,
            middleVerticalBend: middleVerticalBend,
            lineCount: 1,
            laneSpread: 0
        )
        .opacity(0.96)
    }

    private func lifeOSRouteLineCanvas(
        start: CGPoint,
        end: CGPoint,
        colors: [Color],
        curveLift: CGFloat,
        middleHorizontalBend: CGFloat = 0,
        middleVerticalBend: CGFloat = 0,
        lineCount: Int,
        laneSpread: CGFloat
    ) -> some View {
        let connectorSeed = lifeOSConnectorSeed(start: start, end: end, curveLift: curveLift)
        let resolvedColors = lifeOSResolvedConnectorColors(
            colors: colors,
            lineCount: lineCount,
            connectorSeed: connectorSeed
        )
        let resolvedLineCount = max(1, lineCount)
        return IntroRouteLinesCanvas(
            lineCount: resolvedLineCount,
            colors: resolvedColors,
            laneOffsetForIndex: { index, count in
                guard count > 1 else { return 0 }
                let t = CGFloat(index) / CGFloat(max(count - 1, 1))
                return (t * 2 - 1) * laneSpread
            },
            routedPoint: { s, _, laneOffset in
                let p0 = CGPoint(x: start.x, y: start.y + laneOffset * 0.22)
                let p2 = CGPoint(x: end.x, y: end.y + laneOffset * 0.22)
                if middleHorizontalBend > 0.0001 {
                    let control1 = CGPoint(
                        x: p0.x + middleHorizontalBend + laneOffset * 0.08,
                        y: p0.y - curveLift * 0.12 + laneOffset * 0.04
                    )
                    let control2 = CGPoint(
                        x: p2.x + middleHorizontalBend * 0.18 + laneOffset * 0.04,
                        y: p2.y + curveLift * 0.92 + laneOffset * 0.04
                    )
                    return lifeOSCubicPoint(
                        start: p0,
                        control1: control1,
                        control2: control2,
                        end: p2,
                        t: s
                    )
                } else {
                    let control = CGPoint(
                        x: (p0.x + p2.x) / 2 + laneOffset * 0.08,
                        y: ((p0.y + p2.y) / 2) + middleVerticalBend + laneOffset * 0.06 - curveLift
                    )
                    return lifeOSQuadraticPoint(start: p0, control: control, end: p2, t: s)
                }
            },
            lineSeedOffset: connectorSeed,
            lineWidthMultiplier: 0.5
        )
        .allowsHitTesting(false)
        .zIndex(-200)
    }

    private func lifeOSResolvedConnectorColors(
        colors: [Color],
        lineCount: Int,
        connectorSeed: Int
    ) -> [Color] {
        let palette = colors.isEmpty ? [Color.secondary] : colors
        guard lineCount <= 1, palette.count > 1 else { return palette }
        let index = connectorSeed % palette.count
        return [palette[index]]
    }

    private func lifeOSRandomConnectorColor(start: CGPoint, end: CGPoint, fallback: Color) -> Color {
        let palette = lifeOSConnectorPalette
        guard !palette.isEmpty else { return fallback }
        let seed = abs(Int((start.x * 13.0) + (start.y * 7.0) + (end.x * 17.0) + (end.y * 11.0)))
        let index = seed % palette.count
        return palette[index]
    }

    private func lifeOSConnectorSeed(start: CGPoint, end: CGPoint, curveLift: CGFloat) -> Int {
        let raw = Int((start.x * 31.0) + (start.y * 17.0) + (end.x * 13.0) + (end.y * 19.0) + (curveLift * 23.0))
        return abs(raw)
    }

    private func lifeOSQuadraticPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let invT = 1 - t
        let x = (invT * invT * start.x) + (2 * invT * t * control.x) + (t * t * end.x)
        let y = (invT * invT * start.y) + (2 * invT * t * control.y) + (t * t * end.y)
        return CGPoint(x: x, y: y)
    }

    private func lifeOSCubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let invT = 1 - t
        let x =
            (invT * invT * invT * start.x) +
            (3 * invT * invT * t * control1.x) +
            (3 * invT * t * t * control2.x) +
            (t * t * t * end.x)
        let y =
            (invT * invT * invT * start.y) +
            (3 * invT * invT * t * control1.y) +
            (3 * invT * t * t * control2.y) +
            (t * t * t * end.y)
        return CGPoint(x: x, y: y)
    }

    private var lifeOSLittleWinsMiniCardStack: some View {
        let cardColors = lifeOSFulfillmentAreasWithLittleWinsColors
        let cardWidth: CGFloat = 28
        let cardHeight: CGFloat = cardWidth * 1.42
        let radarSideCount = max(3, min(7, lifeOSFulfillmentRadarMetrics.count))
        let horizontalStep: CGFloat = 8
        let visibleColors = Array(cardColors.prefix(6))
        let totalWidth = cardWidth + (CGFloat(max(visibleColors.count - 1, 0)) * horizontalStep)

        return ZStack(alignment: .leading) {
            ForEach(Array(visibleColors.enumerated()), id: \.offset) { index, color in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(width: cardWidth, height: cardHeight)
                    .overlay {
                        LifeOSRadarPolygonOutline(sides: radarSideCount)
                            .stroke(Color.white.opacity(0.86), style: StrokeStyle(lineWidth: 1.4))
                            .padding(4)
                    }
                    .offset(x: CGFloat(max(visibleColors.count - 1 - index, 0)) * horizontalStep)
                    .zIndex(Double(visibleColors.count - index))
            }
        }
        .frame(width: totalWidth, height: cardHeight, alignment: .leading)
    }

    private struct LifeOSRadarPolygonOutline: Shape {
        let sides: Int

        func path(in rect: CGRect) -> Path {
            let clampedSides = max(3, min(7, sides))
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            let startAngle = -CGFloat.pi / 2

            var path = Path()
            for index in 0..<clampedSides {
                let angle = startAngle + (CGFloat(index) * 2 * .pi / CGFloat(clampedSides))
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            return path
        }
    }

    private func fulfillmentRetryRow(
        message: String,
        troubleshooting: String? = nil,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        let hasTroubleshooting = loomAITroubleshootingEnabled && !(troubleshooting ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                HStack(spacing: 10) {
                    Button(buttonTitle, action: action)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    if hasTroubleshooting, let troubleshooting {
                        Button("Copy troubleshooting") {
                            loomAICopyTroubleshootingToClipboard(troubleshooting)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if hasTroubleshooting, let troubleshooting {
                LoomAITroubleshootingSection(details: troubleshooting)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fulfillmentInsightsCard(_ card: FulfillmentInsightCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(0.45)
            Text(card.body)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(autoWriteGradient.opacity(0.68), lineWidth: 1.2)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .trim(from: insightsOutlinePhase, to: min(insightsOutlinePhase + 0.22, 1))
                    .stroke(autoWriteGradient, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        )
    }

    private var fulfillmentInsightsLoadingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 140, height: 11)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.16))
                .frame(height: 12)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.14))
                .frame(height: 12)
        }
        .redacted(reason: .placeholder)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(autoWriteGradient.opacity(0.35), lineWidth: 1)
        )
    }

    private struct FulfillmentInsightsThinkingHeader: View {
        let title: String
        let progress: Double

        @State private var shineOffset: CGFloat = -0.7

        private static let gradientTokens: [Color] = [
            Color(red: 0.22, green: 0.47, blue: 1.0),
            Color(red: 0.15, green: 0.83, blue: 0.95),
            Color(red: 0.62, green: 0.40, blue: 0.95),
            Color(red: 0.80, green: 0.38, blue: 0.78),
            Color(red: 0.98, green: 0.36, blue: 0.58),
            Color(red: 0.22, green: 0.47, blue: 1.0)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image("LoomAI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                GeometryReader { proxy in
                    let fullWidth = max(1, proxy.size.width)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.16))

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: Self.gradientTokens,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fullWidth * max(0, min(1, progress)))

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.0),
                                        Color.white.opacity(0.45),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fullWidth * 0.35)
                            .offset(x: fullWidth * shineOffset)
                    }
                }
                .frame(height: 12)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    shineOffset = 1.2
                }
            }
        }
    }

    @ViewBuilder
    private func categoryDetailsBlock(
        record: Fulfillment,
        includeVisionPurpose: Bool,
        markAsFocus: Bool,
        includeLittleWinsResources: Bool,
        includePassions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(markAsFocus ? "\(record.category) *" : record.category)
                .foregroundStyle(fulfillmentCategoryColor(for: record.category))
            .font(.subheadline.weight(.semibold))

            if includeVisionPurpose {
                summarySubBullet(title: "Mission", values: [record.category_purpose])
            }

            summaryNestedBullets(title: "Identity", values: getRoles(for: record).map(\.role))
            if includeLittleWinsResources {
                summaryNestedBullets(title: "Little Wins", values: getFoci(for: record).map(\.activity))
            }
            if includePassions {
                summaryNestedBullets(
                    title: "Passions",
                    values: selectedPassions(for: record.category_id).map { "\(displayEmotionLabel(for: $0.emotion)): \($0.passion)" }
                )
            }
        }
    }

    @ViewBuilder
    private func summarySubBullet(title: String, values: [String]) -> some View {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !cleaned.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text("\(title):")
                    .font(.subheadline.weight(.semibold))
                Text(cleaned.joined(separator: ", "))
                    .font(.subheadline)
            }
            .padding(.leading, 12)
        }
    }

    @ViewBuilder
    private func summaryNestedBullets(title: String, values: [String]) -> some View {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !cleaned.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(title):")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.leading, 12)

                ForEach(cleaned, id: \.self) { value in
                    HStack(alignment: .top, spacing: 6) {
                        Text("◦")
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.subheadline)
                    }
                    .padding(.leading, 30)
                }
            }
        }
    }

    private var visionIdeasExpander: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNeedIdeasVision.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Need ideas?")
                    Image(systemName: showNeedIdeasVision ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showNeedIdeasVision {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This is not a goal. It’s the long-term direction you want in this area.")
                        .fontWeight(.bold)
                    Text("Focus on how your life feels, how you show up, and what success looks like.")
                    Text("You can refine this anytime. Start simple.")
                    Text("Examples:")
                        .fontWeight(.bold)
                    Text("• I am healthy, energized, and strong, with habits that support long-term vitality and resilience.")
                        .italic()
                    Text("• I feel calm, focused, and in control of this area, which allows me to show up fully in the rest of my life.")
                        .italic()
                    Text("• I consistently grow and improve, creating stability, balance, and confidence in this area.")
                        .italic()
                    Text("• I experience freedom and momentum here, knowing I’m building a strong foundation for my future.")
                        .italic()
                    Text("• This area of my life supports my happiness, creativity, and overall sense of fulfillment.")
                        .italic()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var purposeIdeasExpander: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let record = currentPurposeRecord,
               let suggestions = autoWriteMissionSuggestionsByCategoryID[record.category_id],
               !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        let isApplied = isMissionSuggestionApplied(suggestion, for: record)
                        Button {
                            purposeDrafts[record.category_id] = suggestion
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image("LoomAI")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                    .padding(.top, 1)
                                Text(suggestion)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isApplied)
                    }
                }
            }

            if let record = currentPurposeRecord,
               let error = autoWriteMissionErrorByCategoryID[record.category_id] {
                fulfillmentRetryRow(
                    message: error,
                    troubleshooting: autoWriteMissionTroubleshootingByCategoryID[record.category_id],
                    buttonTitle: "Try again"
                ) {
                    Task { await requestAutoWriteMissionSuggestions(for: record, forceRefresh: true) }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNeedIdeasPurpose.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Need ideas?")
                    Image(systemName: showNeedIdeasPurpose ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showNeedIdeasPurpose {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mission is your deeper reason. It keeps you consistent when motivation fades.")
                        .fontWeight(.bold)
                    Text("Think about why this matters and how your life improves when this area strengthens. When strong, everything feels easier.")
                    Text("You can refine this anytime. Start simple.")
                    Text("Examples:")
                        .fontWeight(.bold)
                    Text("• This fuels my energy and confidence so I can show up fully every day.")
                        .italic()
                    Text("• This gives me stability and peace of mind instead of constant stress.")
                        .italic()
                    Text("• Success here creates freedom and momentum across the rest of my life.")
                        .italic()
                    Text("• I want to feel proud of who I am in this area.")
                        .italic()
                    Text("• Neglecting this always leads to bigger problems later, so it’s a must.")
                        .italic()
                    Text("• This helps me feel grounded, focused, and fulfilled instead of reactive.")
                        .italic()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private struct IdentityAutoWriteSuggestion: Hashable, Codable {
        let id: UUID
        let identity: String
        let replaceIdentity: String?

        init(id: UUID = UUID(), identity: String, replaceIdentity: String?) {
            self.id = id
            self.identity = identity
            self.replaceIdentity = replaceIdentity
        }
    }

    private struct LittleWinAutoWriteSuggestion: Hashable, Codable {
        let id: UUID
        let activity: String
        let replaceActivity: String?

        init(id: UUID = UUID(), activity: String, replaceActivity: String?) {
            self.id = id
            self.activity = activity
            self.replaceActivity = replaceActivity
        }
    }

    private func requestAutoWriteMissionSuggestions(for record: Fulfillment, forceRefresh: Bool = false) async {
        guard isSelectableDefaultCategory(record.category) else {
            autoWriteMissionSuggestionsByCategoryID[record.category_id] = []
            autoWriteMissionErrorByCategoryID[record.category_id] = nil
            autoWriteMissionTroubleshootingByCategoryID[record.category_id] = nil
            return
        }

        let requestKey = missionAutoWriteCacheKey(for: record)
        if !forceRefresh, let cached = autoWriteMissionSuggestionsCache[requestKey], !cached.isEmpty {
            autoWriteMissionSuggestionsByCategoryID[record.category_id] = cached
            autoWriteMissionErrorByCategoryID[record.category_id] = nil
            autoWriteMissionTroubleshootingByCategoryID[record.category_id] = nil
            return
        }
        if !forceRefresh, autoWriteMissionLoadedKeys.contains(requestKey) {
            return
        }
        autoWriteMissionLoadedKeys.insert(requestKey)
        let markFailed = { _ = autoWriteMissionLoadedKeys.remove(requestKey) }

        let previousSuggestions = autoWriteMissionSuggestionsByCategoryID[record.category_id] ?? []
        autoWriteMissionErrorByCategoryID[record.category_id] = nil
        autoWriteMissionTroubleshootingByCategoryID[record.category_id] = nil
        autoWritingMissionCategoryID = record.category_id
        defer { autoWritingMissionCategoryID = nil }
        if forceRefresh || autoWriteMissionSuggestionsCache[requestKey] == nil {
            autoWriteMissionSuggestionsByCategoryID[record.category_id] = []
        }

        let delaySeconds = Int.random(in: 2...5)
        do {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
        } catch {
            markFailed()
            return
        }
        if Task.isCancelled {
            markFailed()
            return
        }

        let candidates = missionSuggestionPool(for: record.category)
        guard !candidates.isEmpty else {
            autoWriteMissionErrorByCategoryID[record.category_id] = "No suggestions yet."
            autoWriteMissionTroubleshootingByCategoryID[record.category_id] = nil
            markFailed()
            return
        }

        let existingMission = normalizedIdentitySuggestion(
            (purposeDrafts[record.category_id] ?? record.category_purpose)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let seen = Set(previousSuggestions.map(normalizedIdentitySuggestion))
        let filtered = candidates.filter { suggestion in
            let normalized = normalizedIdentitySuggestion(suggestion)
            if normalized.isEmpty { return false }
            if !existingMission.isEmpty && normalized == existingMission { return false }
            return !seen.contains(normalized)
        }
        let selectionPool = filtered.isEmpty ? candidates : filtered
        guard let selected = selectionPool.randomElement() else {
            autoWriteMissionErrorByCategoryID[record.category_id] = "No suggestions yet."
            autoWriteMissionTroubleshootingByCategoryID[record.category_id] = nil
            markFailed()
            return
        }

        let nextSuggestions = [selected]
        autoWriteMissionSuggestionsByCategoryID[record.category_id] = nextSuggestions
        autoWriteMissionSuggestionsCache[requestKey] = nextSuggestions
        autoWriteMissionErrorByCategoryID[record.category_id] = nil
        autoWriteMissionTroubleshootingByCategoryID[record.category_id] = nil
    }

    private func missionSuggestionPool(for category: String) -> [String] {
        guard let corpus = fulfillmentStartMissionSuggestionCorpusByCategory.first(where: {
            $0.key.caseInsensitiveCompare(category) == .orderedSame
        })?.value else {
            return []
        }

        return corpus
            .components(separatedBy: .newlines)
            .map(sanitizeMissionSuggestion(_:))
            .filter { !$0.isEmpty }
    }

    private func sanitizeMissionSuggestion(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSelectableDefaultCategory(_ category: String) -> Bool {
        fulfillmentStartSelectableDefaultCategories.contains(where: {
            $0.caseInsensitiveCompare(category) == .orderedSame
        })
    }

    private func truncateMissionSuggestion(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let prefix = String(text.prefix(maxLength))
        if let space = prefix.lastIndex(of: " "), space > prefix.startIndex {
            return String(prefix[..<space]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestAutoWriteIdentitySuggestions(for record: Fulfillment, forceRefresh: Bool = false) async {
        guard isSelectableDefaultCategory(record.category) else {
            autoWriteIdentitySuggestionsByCategoryID[record.category_id] = []
            autoWriteIdentityErrorByCategoryID[record.category_id] = nil
            autoWriteIdentityTroubleshootingByCategoryID[record.category_id] = nil
            return
        }

        let requestKey = identityAutoWriteCacheKey(for: record)
        if !forceRefresh, let cached = autoWriteIdentitySuggestionsCache[requestKey], !cached.isEmpty {
            autoWriteIdentitySuggestionsByCategoryID[record.category_id] = cached
            autoWriteIdentityErrorByCategoryID[record.category_id] = nil
            autoWriteIdentityTroubleshootingByCategoryID[record.category_id] = nil
            return
        }
        if !forceRefresh, autoWriteIdentityLoadedKeys.contains(requestKey) {
            return
        }
        autoWriteIdentityLoadedKeys.insert(requestKey)
        let markFailed = { _ = autoWriteIdentityLoadedKeys.remove(requestKey) }

        let previousSuggestions = autoWriteIdentitySuggestionsByCategoryID[record.category_id] ?? []
        autoWriteIdentityErrorByCategoryID[record.category_id] = nil
        autoWriteIdentityTroubleshootingByCategoryID[record.category_id] = nil
        autoWritingIdentityCategoryID = record.category_id
        defer { autoWritingIdentityCategoryID = nil }
        if forceRefresh || autoWriteIdentitySuggestionsCache[requestKey] == nil {
            autoWriteIdentitySuggestionsByCategoryID[record.category_id] = []
        }

        let delaySeconds = Int.random(in: 2...4)
        do {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
        } catch {
            markFailed()
            return
        }
        if Task.isCancelled {
            markFailed()
            return
        }

        let candidates = identitySuggestionPool(for: record.category)
        guard !candidates.isEmpty else {
            autoWriteIdentityErrorByCategoryID[record.category_id] = "No suggestions yet."
            autoWriteIdentityTroubleshootingByCategoryID[record.category_id] = nil
            markFailed()
            return
        }

        let rolesNow = getRoles(for: record)
        var existingRoleNames = rolesNow.map(\.role)
        if addingRole {
            let pending = roleEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pending.isEmpty {
                existingRoleNames.append(pending)
            }
        }
        let existingRoleSet = Set(existingRoleNames.map(normalizedIdentitySuggestion).filter { !$0.isEmpty })
        let priorSuggestionSet = Set(previousSuggestions.map { normalizedIdentitySuggestion($0.identity) }.filter { !$0.isEmpty })

        let filtered = candidates.filter { identity in
            let normalized = normalizedIdentitySuggestion(identity)
            if normalized.isEmpty { return false }
            return !existingRoleSet.contains(normalized) && !priorSuggestionSet.contains(normalized)
        }
        let nonExisting = candidates.filter { identity in
            let normalized = normalizedIdentitySuggestion(identity)
            if normalized.isEmpty { return false }
            return !existingRoleSet.contains(normalized)
        }

        let primaryPool: [String]
        if filtered.count >= 2 {
            primaryPool = filtered
        } else if nonExisting.count >= 2 {
            primaryPool = nonExisting
        } else {
            primaryPool = candidates
        }

        var picked: [String] = []
        var pickedSet = Set<String>()
        for candidate in primaryPool.shuffled() {
            let normalized = normalizedIdentitySuggestion(candidate)
            if normalized.isEmpty || pickedSet.contains(normalized) { continue }
            picked.append(candidate)
            pickedSet.insert(normalized)
            if picked.count == 2 { break }
        }
        if picked.count < 2 {
            for candidate in candidates.shuffled() {
                let normalized = normalizedIdentitySuggestion(candidate)
                if normalized.isEmpty || pickedSet.contains(normalized) { continue }
                picked.append(candidate)
                pickedSet.insert(normalized)
                if picked.count == 2 { break }
            }
        }

        guard picked.count == 2 else {
            autoWriteIdentityErrorByCategoryID[record.category_id] = "No suggestions yet."
            autoWriteIdentityTroubleshootingByCategoryID[record.category_id] = nil
            markFailed()
            return
        }

        let replaceIdentity = rolesNow.count >= 3 ? weakestIdentityNameForAutoWrite(in: rolesNow) : nil
        let nextSuggestions = picked.compactMap { item -> IdentityAutoWriteSuggestion? in
            let clamped = clampedIdentitySuggestion(item)
            guard !clamped.isEmpty else { return nil }
            return IdentityAutoWriteSuggestion(identity: clamped, replaceIdentity: replaceIdentity)
        }

        guard nextSuggestions.count == 2 else {
            autoWriteIdentityErrorByCategoryID[record.category_id] = "No suggestions yet."
            autoWriteIdentityTroubleshootingByCategoryID[record.category_id] = nil
            markFailed()
            return
        }

        autoWriteIdentitySuggestionsByCategoryID[record.category_id] = nextSuggestions
        autoWriteIdentitySuggestionsCache[requestKey] = nextSuggestions
        autoWriteIdentityErrorByCategoryID[record.category_id] = nil
        autoWriteIdentityTroubleshootingByCategoryID[record.category_id] = nil
    }

    private func identitySuggestionPool(for category: String) -> [String] {
        guard let values = fulfillmentStartIdentitySuggestionMap.first(where: {
            $0.key.caseInsensitiveCompare(category) == .orderedSame
        })?.value else {
            return []
        }

        return values
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .map { $0.replacingOccurrences(of: "fulfillment_area,identity", with: "") }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func weakestIdentityNameForAutoWrite(in roles: [DraftRoleRow]) -> String? {
        guard let weakestID = weakestRoleReplacementID(in: roles) else { return nil }
        return roles
            .first(where: { $0.id == weakestID })?
            .role
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clampedIdentitySuggestion(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        let words = cleaned.split(whereSeparator: \.isWhitespace).prefix(3).joined(separator: " ")
        return truncateMissionSuggestion(words, maxLength: 40)
    }

    private func clampedLittleWinSuggestion(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        let words = cleaned.split(whereSeparator: \.isWhitespace).prefix(7).joined(separator: " ")
        return truncateMissionSuggestion(words, maxLength: 80)
    }

    private func normalizedIdentitySuggestion(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSuggestionTextTooSimilarToExisting(_ candidate: String, existing: [String]) -> Bool {
        let candidateNorm = normalizedIdentitySuggestion(candidate)
        guard !candidateNorm.isEmpty else { return false }
        let candidateTokens = Set(candidateNorm.split(separator: " ").map(String.init))

        for item in existing {
            let itemNorm = normalizedIdentitySuggestion(item)
            if itemNorm.isEmpty { continue }
            if itemNorm == candidateNorm { return true }
            if candidateNorm.contains(itemNorm) || itemNorm.contains(candidateNorm) { return true }

            let itemTokens = Set(itemNorm.split(separator: " ").map(String.init))
            if !itemTokens.isEmpty {
                let overlapCount = candidateTokens.intersection(itemTokens).count
                let overlapRatio = Double(overlapCount) / Double(max(1, min(candidateTokens.count, itemTokens.count)))
                if overlapRatio >= 0.6 { return true }
            }
        }
        return false
    }

    private func isIdentitySuggestionTooSimilarToExisting(_ suggestion: IdentityAutoWriteSuggestion, for record: Fulfillment) -> Bool {
        var existing = getRoles(for: record).map(\.role)
        if addingRole {
            let pending = roleEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pending.isEmpty {
                existing.append(pending)
            }
        }
        return isSuggestionTextTooSimilarToExisting(suggestion.identity, existing: existing)
    }

    private func isLittleWinSuggestionTooSimilarToExisting(_ suggestion: LittleWinAutoWriteSuggestion, for record: Fulfillment) -> Bool {
        var existing = getFoci(for: record).map(\.activity)
        if addingFocus {
            let pending = focusEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pending.isEmpty {
                existing.append(pending)
            }
        }
        return isSuggestionTextTooSimilarToExisting(suggestion.activity, existing: existing)
    }

    private func isMissionSuggestionApplied(_ suggestion: String, for record: Fulfillment) -> Bool {
        let currentMission = (purposeDrafts[record.category_id] ?? record.category_purpose)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedIdentitySuggestion(currentMission) == normalizedIdentitySuggestion(suggestion)
    }

    private func isIdentitySuggestionApplied(_ suggestion: IdentityAutoWriteSuggestion, for record: Fulfillment) -> Bool {
        let rolesNow = getRoles(for: record)
        let normalizedNew = normalizedIdentitySuggestion(suggestion.identity)
        guard !normalizedNew.isEmpty else { return false }
        guard rolesNow.contains(where: { normalizedIdentitySuggestion($0.role) == normalizedNew }) else { return false }

        let replacing = (suggestion.replaceIdentity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacing.isEmpty else { return true }
        if rolesNow.count < 3 { return true }

        let normalizedReplacing = normalizedIdentitySuggestion(replacing)
        return !rolesNow.contains(where: { normalizedIdentitySuggestion($0.role) == normalizedReplacing })
    }

    private func isLittleWinSuggestionApplied(_ suggestion: LittleWinAutoWriteSuggestion, for record: Fulfillment) -> Bool {
        let littleWinsNow = getFoci(for: record)
        let normalizedNew = normalizedIdentitySuggestion(suggestion.activity)
        guard !normalizedNew.isEmpty else { return false }
        guard littleWinsNow.contains(where: { normalizedIdentitySuggestion($0.activity) == normalizedNew }) else { return false }

        let replacing = (suggestion.replaceActivity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacing.isEmpty else { return true }
        if littleWinsNow.count < 3 { return true }

        let normalizedReplacing = normalizedIdentitySuggestion(replacing)
        return !littleWinsNow.contains(where: { normalizedIdentitySuggestion($0.activity) == normalizedReplacing })
    }

    private func suggestionTopLine(
        _ suggestion: IdentityAutoWriteSuggestion,
        category: String,
        isApplied: Bool,
        showReplaceContext: Bool
    ) -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplace = showReplaceContext && (suggestion.replaceIdentity ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let verb = isApplied ? (isReplace ? "Replaced" : "Added") : (isReplace ? "Replace" : "Add")
        if isReplace {
            return trimmedCategory.isEmpty ? "\(verb) Identity:" : "\(verb) Identity in \(trimmedCategory):"
        }
        return trimmedCategory.isEmpty ? "\(verb) Identity:" : "\(verb) Identity to \(trimmedCategory):"
    }

    private func applyIdentityAutoWriteSuggestion(_ suggestion: IdentityAutoWriteSuggestion, for record: Fulfillment) -> Bool {
        let newIdentity = suggestion.identity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newIdentity.isEmpty else { return false }

        let existing = getRoles(for: record)
        let normalizedNew = newIdentity.lowercased()
        if existing.contains(where: { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedNew }) {
            return false
        }

        if existing.count < 3 {
            addRole(text: newIdentity, record: record)
            return true
        }

        let explicitTarget = (suggestion.replaceIdentity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetID = roleReplacementTargetID(for: explicitTarget, roles: existing)
            ?? weakestRoleReplacementID(in: existing),
           let idx = draftRoles.firstIndex(where: { $0.id == targetID }) {
            draftRoles[idx].role = newIdentity
            draftRoles[idx].updatedAt = Date()
            if draftRoles[idx].rank == 1 {
                record.category_identitiy = newIdentity
                record.updatedAt = Date()
            }
            persistDraftIfNeeded()
            return true
        }
        return false
    }

    private func roleReplacementTargetID(for target: String, roles: [DraftRoleRow]) -> UUID? {
        let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTarget.isEmpty else { return nil }
        return roles.first(where: { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTarget })?.id
    }

    private func weakestRoleReplacementID(in roles: [DraftRoleRow]) -> UUID? {
        roles
            .sorted { lhs, rhs in
                let lhsScore = identityStrengthScore(lhs.role)
                let rhsScore = identityStrengthScore(rhs.role)
                if lhsScore == rhsScore { return lhs.rank > rhs.rank }
                return lhsScore < rhsScore
            }
            .first?
            .id
    }

    private func identityStrengthScore(_ role: String) -> Int {
        let normalized = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return 0 }
        let genericTokens = ["person", "good", "better", "best", "role", "identity", "helper", "worker", "member"]
        if genericTokens.contains(where: { normalized == $0 }) { return 1 }
        if normalized.count <= 4 { return 2 }
        if normalized.split(separator: " ").count <= 1 { return 3 }
        return 4
    }

    private func requestAutoWriteLittleWinSuggestions(for record: Fulfillment, forceRefresh: Bool = false) async {
        guard isSelectableDefaultCategory(record.category) else {
            autoWriteLittleWinSuggestionsByCategoryID[record.category_id] = []
            autoWriteLittleWinErrorByCategoryID[record.category_id] = nil
            autoWriteLittleWinTroubleshootingByCategoryID[record.category_id] = nil
            return
        }

        let requestKey = littleWinAutoWriteCacheKey(for: record)
        if !forceRefresh, let cached = autoWriteLittleWinSuggestionsCache[requestKey], !cached.isEmpty {
            autoWriteLittleWinSuggestionsByCategoryID[record.category_id] = cached
            autoWriteLittleWinErrorByCategoryID[record.category_id] = nil
            autoWriteLittleWinTroubleshootingByCategoryID[record.category_id] = nil
            return
        }
        if !forceRefresh, autoWriteLittleWinLoadedKeys.contains(requestKey) {
            return
        }
        autoWriteLittleWinLoadedKeys.insert(requestKey)
        let markFailed = { _ = autoWriteLittleWinLoadedKeys.remove(requestKey) }

        let previousSuggestions = autoWriteLittleWinSuggestionsByCategoryID[record.category_id] ?? []
        autoWriteLittleWinErrorByCategoryID[record.category_id] = nil
        autoWriteLittleWinTroubleshootingByCategoryID[record.category_id] = nil
        autoWritingLittleWinCategoryID = record.category_id
        defer { autoWritingLittleWinCategoryID = nil }
        if forceRefresh || autoWriteLittleWinSuggestionsCache[requestKey] == nil {
            autoWriteLittleWinSuggestionsByCategoryID[record.category_id] = []
        }

        let delaySeconds = Int.random(in: 2...4)
        do {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
        } catch {
            markFailed()
            return
        }
        if Task.isCancelled {
            markFailed()
            return
        }

        let candidates = littleWinSuggestionPool(for: record.category)
        guard !candidates.isEmpty else {
            autoWriteLittleWinErrorByCategoryID[record.category_id] = "No suggestions yet."
            autoWriteLittleWinTroubleshootingByCategoryID[record.category_id] = nil
            markFailed()
            return
        }

        let littleWinsNow = getFoci(for: record)
        var existingLittleWinNames = littleWinsNow.map(\.activity)
        if addingFocus {
            let pending = focusEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pending.isEmpty {
                existingLittleWinNames.append(pending)
            }
        }
        let existingSet = Set(existingLittleWinNames.map(normalizedIdentitySuggestion).filter { !$0.isEmpty })
        let priorSuggestionSet = Set(previousSuggestions.map { normalizedIdentitySuggestion($0.activity) }.filter { !$0.isEmpty })

        let filtered = candidates.filter { activity in
            let normalized = normalizedIdentitySuggestion(activity)
            if normalized.isEmpty { return false }
            return !existingSet.contains(normalized) && !priorSuggestionSet.contains(normalized)
        }
        let nonExisting = candidates.filter { activity in
            let normalized = normalizedIdentitySuggestion(activity)
            if normalized.isEmpty { return false }
            return !existingSet.contains(normalized)
        }

        let primaryPool: [String]
        if filtered.count >= 2 {
            primaryPool = filtered
        } else if nonExisting.count >= 2 {
            primaryPool = nonExisting
        } else {
            primaryPool = candidates
        }

        var picked: [String] = []
        var pickedSet = Set<String>()
        for candidate in primaryPool.shuffled() {
            let normalized = normalizedIdentitySuggestion(candidate)
            if normalized.isEmpty || pickedSet.contains(normalized) { continue }
            picked.append(candidate)
            pickedSet.insert(normalized)
            if picked.count == 2 { break }
        }
        if picked.count < 2 {
            for candidate in candidates.shuffled() {
                let normalized = normalizedIdentitySuggestion(candidate)
                if normalized.isEmpty || pickedSet.contains(normalized) { continue }
                picked.append(candidate)
                pickedSet.insert(normalized)
                if picked.count == 2 { break }
            }
        }

        guard picked.count == 2 else {
            autoWriteLittleWinErrorByCategoryID[record.category_id] = "No suggestions yet."
            autoWriteLittleWinTroubleshootingByCategoryID[record.category_id] = nil
            markFailed()
            return
        }

        let replaceActivity = littleWinsNow.count >= 3 ? weakestLittleWinNameForAutoWrite(in: littleWinsNow) : nil
        let nextSuggestions = picked.compactMap { item -> LittleWinAutoWriteSuggestion? in
            let clamped = clampedLittleWinSuggestion(item)
            guard !clamped.isEmpty else { return nil }
            return LittleWinAutoWriteSuggestion(activity: clamped, replaceActivity: replaceActivity)
        }

        guard nextSuggestions.count == 2 else {
            autoWriteLittleWinErrorByCategoryID[record.category_id] = "No suggestions yet."
            autoWriteLittleWinTroubleshootingByCategoryID[record.category_id] = nil
            markFailed()
            return
        }

        autoWriteLittleWinSuggestionsByCategoryID[record.category_id] = nextSuggestions
        autoWriteLittleWinSuggestionsCache[requestKey] = nextSuggestions
        autoWriteLittleWinErrorByCategoryID[record.category_id] = nil
        autoWriteLittleWinTroubleshootingByCategoryID[record.category_id] = nil
    }

    private func littleWinSuggestionPool(for category: String) -> [String] {
        if isHealthEnergyCategory(category) {
            return fulfillmentStartHealthEnergyLittleWinFlags
                .map(\.activity)
                .map { $0.replacingOccurrences(of: "\"", with: "") }
                .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        guard let corpus = fulfillmentStartLittleWinCorpusByCategory.first(where: {
            $0.key.caseInsensitiveCompare(category) == .orderedSame
        })?.value else {
            return []
        }

        return corpus
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isHealthEnergyCategory(_ category: String) -> Bool {
        category.caseInsensitiveCompare("Health & Energy") == .orderedSame
    }

    private func isAppleHealthIntegrationFriendlyLittleWin(_ activity: String, category: String) -> Bool {
        guard isHealthEnergyCategory(category) else { return false }
        let normalized = activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return fulfillmentStartHealthEnergyAppleHealthLittleWins.contains(normalized)
    }

    private func weakestLittleWinNameForAutoWrite(in littleWins: [DraftFocusRow]) -> String? {
        guard let weakestID = weakestLittleWinReplacementID(in: littleWins) else { return nil }
        return littleWins
            .first(where: { $0.id == weakestID })?
            .activity
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct FulfillmentInsightsResponse: Decodable {
        struct Card: Decodable {
            let title: String?
            let body: String?
            let text: String?
            let message: String?
        }
        let cards: [Card]?
        let confidence: String?
        let nudge: String?
    }

    private struct FulfillmentInsightsPersistedCard: Codable {
        let title: String
        let body: String
    }

    private struct FulfillmentInsightsPersistedEntry: Codable {
        let cacheKey: String
        let savedAt: Date
        let cards: [FulfillmentInsightsPersistedCard]
        let nudge: String?
    }

    private func handleAutoStartForStep(_ targetStep: Step) {
        switch targetStep {
        case .purposeSweep:
            guard let record = currentPurposeRecord, isSelectableDefaultCategory(record.category) else { return }
            Task { await requestAutoWriteMissionSuggestions(for: record) }
        case .roles:
            guard let record = currentRoleRecord, isSelectableDefaultCategory(record.category) else { return }
            Task { await requestAutoWriteIdentitySuggestions(for: record) }
        case .littleWins:
            guard let record = currentDeepRecord, isSelectableDefaultCategory(record.category) else { return }
            Task { await requestAutoWriteLittleWinSuggestions(for: record) }
        case .insights:
            break
        default:
            break
        }
    }

    private func missionAutoWriteCacheKey(for record: Fulfillment) -> String {
        let missionText = (purposeDrafts[record.category_id] ?? record.category_purpose)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "mission|\(record.category_id.uuidString)|\(stableHash(personalizationSignature() + "|" + missionText))"
    }

    private func identityAutoWriteCacheKey(for record: Fulfillment) -> String {
        let rolesText = getRoles(for: record)
            .map(\.role)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
        return "identity|\(record.category_id.uuidString)|\(stableHash(personalizationSignature() + "|" + rolesText))"
    }

    private func littleWinAutoWriteCacheKey(for record: Fulfillment) -> String {
        let mission = (purposeDrafts[record.category_id] ?? record.category_purpose)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let identities = getRoles(for: record)
            .map(\.role)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
        let currentLittleWins = getFoci(for: record)
            .map(\.activity)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
        return "littlewins|\(record.category_id.uuidString)|\(stableHash(personalizationSignature() + "|" + mission + "|" + identities + "|" + currentLittleWins))"
    }

    private var fulfillmentInsightsCacheKey: String {
        let diagnosticsHash = stableHash(personalizationSignature())
        let purposeHash = stableHash(purposeContextSignature())
        let fulfillmentHash = stableHash(fulfillmentSelectionSignature())
        return "fulfillment_insights|\(Self.fulfillmentInsightsPromptVersion)|\(diagnosticsHash)|\(purposeHash)|\(fulfillmentHash)"
    }

    private func purposeContextSignature() -> String {
        let drivingForce = drivingForces.first
        let vision = (drivingForce?.ultimateVision ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let purpose = (drivingForce?.ultimatePurpose ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let passionSignal = passions
            .map { "\($0.emotion.lowercased()):\($0.passion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())" }
            .sorted()
            .joined(separator: "|")
        return [vision, purpose, passionSignal].joined(separator: "||")
    }

    private func fulfillmentSelectionSignature() -> String {
        orderedFulfillments
            .map { record in
                let mission = (purposeDrafts[record.category_id] ?? record.category_purpose)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let identities = getRoles(for: record)
                    .map(\.role)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .sorted()
                    .joined(separator: "|")
                let littleWins = getFoci(for: record)
                    .map(\.activity)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .sorted()
                    .joined(separator: "|")
                return [
                    record.category_id.uuidString.lowercased(),
                    record.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    mission,
                    identities,
                    littleWins
                ].joined(separator: "::")
            }
            .sorted()
            .joined(separator: "||")
    }

    private func personalizationSignature() -> String {
        guard let snapshot = personalizationSnapshot else { return "none" }
        let parts: [String] = [
            snapshot.createdAt.ISO8601Format(),
            snapshot.stressSource,
            snapshot.breakPoint,
            snapshot.lifeAreasSelected.joined(separator: "|"),
            snapshot.planningReality,
            snapshot.desiredChange
        ]
        return parts.joined(separator: "||")
    }

    private func stableHash(_ raw: String) -> String {
        raw.unicodeScalars.reduce(UInt64(5381)) { acc, scalar in
            ((acc << 5) &+ acc) &+ UInt64(scalar.value)
        }
        .description
    }

    private func generateFulfillmentInsights(forceRefresh: Bool = false) async {
        let requestKey = fulfillmentInsightsCacheKey
        #if DEBUG
        print("[FulfillmentInsights] key=\(requestKey) cached=\((fulfillmentInsightsCache[requestKey]?.isEmpty == false)) active=\(fulfillmentInsightsActiveRequestKey == requestKey)")
        #endif
        if !forceRefresh, let cached = fulfillmentInsightsCache[requestKey], !cached.isEmpty {
            fulfillmentInsightCards = cached
            fulfillmentInsightsNudgeMessage = fulfillmentInsightsNudgeCache[requestKey]
            fulfillmentInsightsErrorMessage = nil
            fulfillmentInsightsTroubleshootingMessage = nil
            return
        }
        if !forceRefresh,
           let persisted = persistedFulfillmentInsights(for: requestKey) {
            fulfillmentInsightCards = persisted.cards
            fulfillmentInsightsNudgeMessage = persisted.nudge
            fulfillmentInsightsErrorMessage = nil
            fulfillmentInsightsTroubleshootingMessage = nil
            fulfillmentInsightsCache[requestKey] = persisted.cards
            if let nudge = persisted.nudge {
                fulfillmentInsightsNudgeCache[requestKey] = nudge
            }
            return
        }
        if !forceRefresh, fulfillmentInsightsActiveRequestKey == requestKey {
            return
        }

        fulfillmentInsightsErrorMessage = nil
        fulfillmentInsightsNudgeMessage = nil
        fulfillmentInsightsTroubleshootingMessage = nil
        fulfillmentInsightsActiveRequestKey = requestKey
        isGeneratingFulfillmentInsights = true
        if fulfillmentInsightCards.isEmpty || forceRefresh {
            fulfillmentInsightCards = []
        }
        defer {
            if fulfillmentInsightsActiveRequestKey == requestKey {
                fulfillmentInsightsActiveRequestKey = nil
            }
            isGeneratingFulfillmentInsights = false
        }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let payloadJSON = fulfillmentInsightsPayloadJSONString()
            let instruction = """
            Generate Fulfillment onboarding insights for Loom.
            Fulfillment onboarding payload JSON:
            \(payloadJSON)

            Requirements:
            - Return JSON only with exactly 2 cards.
            - Card 1 title: Fulfillment areas
            - Card 2 title: Next direction
            - Do not list selected category names and do not say "You selected".
            - Do not rename or re-label selected fulfillment areas.
            - Ground cards in diagnostics + purpose + fulfillment setup evidence only.
            - Keep each card to 2-3 sentences with calm, practical language.
            - If diagnostics or purpose are missing, say that briefly and provide a useful fallback without inventing claims.
            - Next direction must end with a final sentence that starts with "Loom will help you".
            """

            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: instruction)],
                context: contextSnapshot,
                intent: "onboarding_insights_fulfillment",
                screen: "fulfillment_insights",
                requestID: UUID().uuidString,
                requestHash: requestKey
            )
            let decoded = decodeFulfillmentInsights(from: response.message)
            guard !decoded.cards.isEmpty else {
                guard requestKey == fulfillmentInsightsCacheKey else { return }
                fulfillmentInsightCards = defaultFulfillmentInsightsCards()
                fulfillmentInsightsErrorMessage = "Couldn’t generate insights yet."
                fulfillmentInsightsTroubleshootingMessage = loomAITroubleshootingLocalDetails(
                    feature: "fulfillment_start_insights",
                    reason: "No insight cards could be parsed from the response.",
                    responsePreview: response.message,
                    requestHash: requestKey
                )
                return
            }
            guard requestKey == fulfillmentInsightsCacheKey else { return }
            fulfillmentInsightCards = decoded.cards
            fulfillmentInsightsNudgeMessage = decoded.nudge
            fulfillmentInsightsTroubleshootingMessage = nil
            fulfillmentInsightsCache[requestKey] = decoded.cards
            if let nudge = decoded.nudge {
                fulfillmentInsightsNudgeCache[requestKey] = nudge
            } else {
                fulfillmentInsightsNudgeCache.removeValue(forKey: requestKey)
            }
            persistFulfillmentInsights(
                for: requestKey,
                cards: decoded.cards,
                nudge: decoded.nudge
            )
        } catch {
            guard requestKey == fulfillmentInsightsCacheKey else { return }
            fulfillmentInsightCards = defaultFulfillmentInsightsCards()
            fulfillmentInsightsErrorMessage = "Couldn’t generate insights yet."
            fulfillmentInsightsTroubleshootingMessage = loomAITroubleshootingDetails(
                feature: "fulfillment_start_insights",
                error: error,
                requestHash: requestKey
            )
        }
    }

    private func fulfillmentInsightsPayloadJSONString() -> String {
        let diagnostics = personalizationSnapshot.map { snapshot in
            [
                "stressSource": snapshot.stressSource,
                "breakPoint": snapshot.breakPoint,
                "planningReality": snapshot.planningReality,
                "desiredChange": snapshot.desiredChange,
                "lifeAreasSelected": snapshot.lifeAreasSelected,
                "createdAt": snapshot.createdAt.ISO8601Format()
            ] as [String: Any]
        } ?? [
            "missing": true
        ]
        let categoriesPayload: [[String: Any]] = orderedFulfillments.map { record in
            [
                "categoryID": record.category_id.uuidString,
                "category": record.category,
                "mission": (purposeDrafts[record.category_id] ?? record.category_purpose),
                "identities": getRoles(for: record).map(\.role),
                "littleWins": getFoci(for: record).map(\.activity),
                "resources": getResources(for: record).map(\.resource),
                "passions": selectedPassions(for: record.category_id).map { "\(displayEmotionLabel(for: $0.emotion)): \($0.passion)" }
            ]
        }
        let priorityNames = priorityCategoryIDs.compactMap { id in
            orderedFulfillments.first(where: { $0.category_id == id })?.category
        }
        let purposePayload: [String: Any] = [
            "vision": drivingForces.first?.ultimateVision ?? "",
            "purpose": drivingForces.first?.ultimatePurpose ?? "",
            "passions": passions
                .map { "\(displayEmotionLabel(for: $0.emotion)): \($0.passion)" }
                .sorted()
        ]
        let payload: [String: Any] = [
            "diagnostics": diagnostics,
            "purpose": purposePayload,
            "selectedCategoryNames": orderedFulfillments.map(\.category),
            "priorityCategoryNames": priorityNames,
            "categories": categoriesPayload
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted]),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private func decodeFulfillmentInsights(from raw: String) -> (cards: [FulfillmentInsightCard], nudge: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitles = ["Fulfillment areas", "Next direction"]
        let fallbackCards = defaultFulfillmentInsightsCards()
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(FulfillmentInsightsResponse.self, from: data) {
            let bodies = (parsed.cards ?? []).compactMap { card -> String? in
                let body = (card.body ?? card.text ?? card.message ?? "")
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return body.isEmpty ? nil : body
            }
            let areasCandidate = bodies.indices.contains(0) ? bodies[0] : fallbackCards[0].body
            let nextCandidate = bodies.indices.contains(1) ? bodies[1] : fallbackCards[1].body

            let cards: [FulfillmentInsightCard] = [
                FulfillmentInsightCard(
                    title: defaultTitles[0],
                    body: validatedFulfillmentAreasBody(
                        candidate: areasCandidate,
                        fallback: fallbackCards[0].body
                    )
                ),
                FulfillmentInsightCard(
                    title: defaultTitles[1],
                    body: validatedNextDirectionBody(
                        candidate: nextCandidate,
                        fallback: fallbackCards[1].body
                    )
                )
            ]
            let nudge = parsed.nudge?
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (cards, nudge?.isEmpty == true ? nil : nudge)
        }

        let fallbackBodies = trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if fallbackBodies.count >= 2 {
            return (
                [
                    FulfillmentInsightCard(
                        title: defaultTitles[0],
                        body: validatedFulfillmentAreasBody(
                            candidate: fallbackBodies[0],
                            fallback: fallbackCards[0].body
                        )
                    ),
                    FulfillmentInsightCard(
                        title: defaultTitles[1],
                        body: validatedNextDirectionBody(
                            candidate: fallbackBodies[1],
                            fallback: fallbackCards[1].body
                        )
                    )
                ],
                nil
            )
        }
        return (fallbackCards, nil)
    }

    private func defaultFulfillmentInsightsCards() -> [FulfillmentInsightCard] {
        let categoryCount = orderedFulfillments.count
        let categoryCountHint: String
        if categoryCount < 3 {
            categoryCountHint = "You may need a few more areas for full coverage; aim for 3-7."
        } else if categoryCount > 7 {
            categoryCountHint = "You may have too many areas to stay clear; aim for 3-7."
        } else {
            categoryCountHint = ""
        }
        let areasBody = defaultFulfillmentAreasBody(categoryCountHint: categoryCountHint)
        let nextDirectionBody = defaultFulfillmentNextDirectionBody()

        return [
            FulfillmentInsightCard(
                title: "Fulfillment areas",
                body: areasBody
            ),
            FulfillmentInsightCard(
                title: "Next direction",
                body: nextDirectionBody
            )
        ]
    }

    private func validatedFulfillmentAreasBody(candidate: String, fallback: String) -> String {
        let normalized = candidate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return fallback }
        let lower = normalized.lowercased()
        if lower.contains("you selected") || lower.contains("you chose") {
            return fallback
        }
        let matchedCategoryCount = orderedFulfillments.reduce(0) { partial, record in
            let category = record.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !category.isEmpty else { return partial }
            return lower.contains(category) ? partial + 1 : partial
        }
        if matchedCategoryCount >= 1 {
            return fallback
        }
        return clampedInsightSentences(
            normalized,
            fallback: fallback,
            minSentences: 2,
            maxSentences: 3,
            maxLength: 520
        )
    }

    private func validatedNextDirectionBody(candidate: String, fallback: String) -> String {
        let normalized = candidate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = normalized.isEmpty ? ensureNextDirectionEnding(fallback) : ensureNextDirectionEnding(normalized)
        return clampedInsightSentences(
            base,
            fallback: ensureNextDirectionEnding(fallback),
            minSentences: 2,
            maxSentences: 3,
            maxLength: 540
        )
    }

    private func ensureNextDirectionEnding(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "We’ll narrow your planning to fewer priorities so progress feels steady and sustainable. Loom will help you keep decisions simple and follow-through consistent."
        }

        var sentences = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if sentences.isEmpty {
            sentences = [trimmed]
        }

        if let loomIndex = sentences.firstIndex(where: { $0.lowercased().hasPrefix("loom will help you") }) {
            let loomSentence = sentences.remove(at: loomIndex)
            sentences.append(loomSentence)
        } else {
            sentences.append("Loom will help you stay focused on fewer priorities with steadier follow-through")
        }

        if sentences.count > 3 {
            let last = sentences.last ?? "Loom will help you stay focused on fewer priorities with steadier follow-through"
            sentences = Array(sentences.prefix(2)) + [last]
        }

        let joined = sentences.map { sentence in
            sentence.hasSuffix(".") ? sentence : "\(sentence)."
        }
        .joined(separator: " ")
        return truncateMissionSuggestion(joined, maxLength: 540)
    }

    private func clampedInsightSentences(
        _ raw: String,
        fallback: String,
        minSentences: Int,
        maxSentences: Int,
        maxLength: Int
    ) -> String {
        let trimmed = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTrimmed = fallback
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallbackTrimmed }

        var sentences = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if sentences.isEmpty {
            sentences = [trimmed]
        }

        if sentences.count > maxSentences {
            sentences = Array(sentences.prefix(maxSentences))
        }

        let fallbackSentences = fallbackTrimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        while sentences.count < minSentences, let extra = fallbackSentences.dropFirst(sentences.count).first {
            sentences.append(extra)
        }

        var output = sentences
            .map { $0.hasSuffix(".") ? $0 : "\($0)." }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if output.count > maxLength {
            output = truncateMissionSuggestion(output, maxLength: maxLength)
            if !output.hasSuffix(".") {
                output += "."
            }
        }

        return output
    }

    private func defaultFulfillmentAreasBody(categoryCountHint: String) -> String {
        let desiredChange = personalizationSnapshot?
            .desiredChange
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stressSource = personalizationSnapshot?
            .stressSource
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let purposeSignal = (drivingForces.first?.ultimatePurpose ?? drivingForces.first?.ultimateVision ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let contextClause: String
        if !desiredChange.isEmpty && !purposeSignal.isEmpty {
            contextClause = "Given your goal of \(desiredChange.lowercased()) and the direction in your Purpose,"
        } else if !desiredChange.isEmpty {
            contextClause = "Given your goal of \(desiredChange.lowercased()),"
        } else if !stressSource.isEmpty {
            contextClause = "Given the pressure you feel around \(stressSource.lowercased()),"
        } else if !purposeSignal.isEmpty {
            contextClause = "Given the direction in your Purpose,"
        } else {
            contextClause = "I don’t have full Purpose and diagnostic context yet, so this is a baseline:"
        }

        return [
            "\(contextClause) a well-rounded setup keeps coverage broad enough to avoid blind spots without creating overload.",
            "Loom will use fulfillment areas as a stable map so tasks, goals, and little wins stay connected to long-term direction.",
            categoryCountHint
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private func defaultFulfillmentNextDirectionBody() -> String {
        let planning = personalizationSnapshot?
            .planningReality
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let desiredChange = personalizationSnapshot?
            .desiredChange
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        let firstSentence: String
        if planning.contains("reactive") || planning.contains("behind") || planning.contains("drift") || planning.contains("overwhelm") {
            firstSentence = "We’ll shorten the planning horizon and tighten priorities so execution stays predictable instead of reactive."
        } else if !desiredChange.isEmpty {
            firstSentence = "We’ll align weekly priorities to your desired shift toward \(desiredChange) so momentum stays clear and sustainable."
        } else {
            firstSentence = "We’ll keep priorities narrower and sequencing clearer so progress stays steady without constant re-planning."
        }

        return ensureNextDirectionEnding(
            "\(firstSentence) Loom will help you maintain consistent follow-through with simpler decisions and less overwhelm."
        )
    }

    private func persistedFulfillmentInsights(for cacheKey: String) -> (cards: [FulfillmentInsightCard], nudge: String?)? {
        guard let data = fulfillmentInsightsCacheStorage.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: FulfillmentInsightsPersistedEntry].self, from: data),
              let entry = map[cacheKey] else {
            return nil
        }

        let cards = entry.cards.map { FulfillmentInsightCard(title: $0.title, body: $0.body) }
        guard !cards.isEmpty else { return nil }
        let nudge = entry.nudge?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (Array(cards.prefix(2)), nudge?.isEmpty == true ? nil : nudge)
    }

    private func persistFulfillmentInsights(
        for cacheKey: String,
        cards: [FulfillmentInsightCard],
        nudge: String?
    ) {
        let normalizedCards = Array(cards.prefix(2))
            .map { FulfillmentInsightsPersistedCard(title: $0.title, body: $0.body) }
        guard !normalizedCards.isEmpty else { return }

        var map: [String: FulfillmentInsightsPersistedEntry] = [:]
        if let data = fulfillmentInsightsCacheStorage.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: FulfillmentInsightsPersistedEntry].self, from: data) {
            map = decoded
        }

        map[cacheKey] = FulfillmentInsightsPersistedEntry(
            cacheKey: cacheKey,
            savedAt: .now,
            cards: normalizedCards,
            nudge: nudge?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if map.count > 24 {
            let sortedKeys = map
                .sorted { lhs, rhs in lhs.value.savedAt > rhs.value.savedAt }
                .map(\.key)
            let keep = Set(sortedKeys.prefix(24))
            map = map.filter { keep.contains($0.key) }
        }

        if let encoded = try? JSONEncoder().encode(map),
           let jsonString = String(data: encoded, encoding: .utf8) {
            fulfillmentInsightsCacheStorage = jsonString
        }
    }

    private func littleWinSuggestionTopLine(
        _ suggestion: LittleWinAutoWriteSuggestion,
        category: String,
        isApplied: Bool,
        showReplaceContext: Bool
    ) -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplace = showReplaceContext && (suggestion.replaceActivity ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let verb = isApplied ? (isReplace ? "Replaced" : "Added") : (isReplace ? "Replace" : "Add")
        if isReplace {
            return trimmedCategory.isEmpty ? "\(verb) Little Win:" : "\(verb) Little Win in \(trimmedCategory):"
        }
        return trimmedCategory.isEmpty ? "\(verb) Little Win:" : "\(verb) Little Win to \(trimmedCategory):"
    }

    private func applyLittleWinAutoWriteSuggestion(_ suggestion: LittleWinAutoWriteSuggestion, for record: Fulfillment) -> Bool {
        let newActivity = suggestion.activity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newActivity.isEmpty else { return false }

        let existing = getFoci(for: record)
        let normalizedNew = newActivity.lowercased()
        if existing.contains(where: { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedNew }) {
            return false
        }

        if existing.count < 3 {
            addFocus(text: newActivity, record: record)
            return true
        }

        let explicitTarget = (suggestion.replaceActivity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetID = littleWinReplacementTargetID(for: explicitTarget, littleWins: existing)
            ?? weakestLittleWinReplacementID(in: existing),
           let idx = draftFoci.firstIndex(where: { $0.id == targetID }) {
            draftFoci[idx].activity = newActivity
            draftFoci[idx].updatedAt = Date()
            persistDraftIfNeeded()
            return true
        }
        return false
    }

    private func littleWinReplacementTargetID(for target: String, littleWins: [DraftFocusRow]) -> UUID? {
        let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTarget.isEmpty else { return nil }
        return littleWins.first(where: { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTarget })?.id
    }

    private func weakestLittleWinReplacementID(in littleWins: [DraftFocusRow]) -> UUID? {
        littleWins
            .sorted { lhs, rhs in
                let lhsScore = littleWinStrengthScore(lhs.activity)
                let rhsScore = littleWinStrengthScore(rhs.activity)
                if lhsScore == rhsScore { return lhs.rank > rhs.rank }
                return lhsScore < rhsScore
            }
            .first?
            .id
    }

    private func littleWinStrengthScore(_ activity: String) -> Int {
        let normalized = activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return 0 }
        let genericTokens = ["work", "exercise", "task", "habit", "routine", "improve"]
        if genericTokens.contains(where: { normalized == $0 }) { return 1 }
        if normalized.count <= 6 { return 2 }
        if normalized.split(separator: " ").count <= 1 { return 3 }
        return 4
    }

    private func categoryHeader(_ title: String, index: Int, total: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(fulfillmentCategoryColor(for: title))
            Spacer(minLength: 8)
            Text("\(index)/\(max(total, 1))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func phaseSubtext(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func summarySection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content,
        onEdit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.caption.weight(.semibold))
            }
            content()
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func multiLineEditor(text: Binding<String>, placeholder: String, showError: Bool = false) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.system(size: 19))
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .lineLimit(2...8)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 88, alignment: .topLeading)
            .background(editorSurfaceColor, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showError ? Color.red.opacity(0.8) : Color(.separator).opacity(0.5), lineWidth: showError ? 1.6 : 1)
            )
    }

    // MARK: - Navigation

    private func goBack() {
        if Date() < ignoreBackUntil {
            return
        }
        switch step {
        case .createCategories:
            if isAddSingleAreaMode {
                dismiss()
            } else {
                step = .intro
            }
        case .visionSweep:
            step = .createCategories
        case .purposeSweep:
            if purposeIndex > 0 {
                purposeIndex -= 1
            } else {
                step = .createCategories
            }
        case .roles:
            if roleIndex > 0 {
                roleIndex -= 1
            } else {
                step = .purposeSweep
                purposeIndex = max(orderedFulfillments.count - 1, 0)
            }
        case .priorities:
            step = .roles
            roleIndex = max(roleCategoryIDs.count - 1, 0)
        case .littleWins:
            if deepIndex > 0 {
                deepIndex -= 1
            } else {
                step = isAddSingleAreaMode ? .roles : .priorities
            }
        case .resources:
            if deepIndex > 0 {
                deepIndex -= 1
            } else {
                step = .littleWins
                deepIndex = max(deepCategoryIDs.count - 1, 0)
            }
        case .passions:
            if passionIndex > 0 {
                passionIndex -= 1
            } else {
                step = .littleWins
                deepIndex = max(deepCategoryIDs.count - 1, 0)
            }
        case .summary:
            step = .passions
            passionIndex = max(roleCategoryIDs.count - 1, 0)
        case .insights:
            step = .summary
        case .intro:
            dismiss()
        }
    }

    private func advanceFromCurrentStep() {
        switch step {
        case .createCategories:
            syncSelectedCategoriesIntoFulfillment()
            visionIndex = 0
            purposeIndex = 0
            roleIndex = 0
            deepIndex = 0
            passionIndex = 0
            didOpenPriorities = false
            step = .purposeSweep
        case .visionSweep:
            moveVisionForward(saveCurrent: true)
        case .purposeSweep:
            movePurposeForward(saveCurrent: true)
        case .roles:
            if let record = currentRoleRecord, addingRole {
                commitRole(record)
            }
            if roleIndex < roleCategoryIDs.count - 1 {
                roleIndex += 1
            } else {
                if isAddSingleAreaMode {
                    deepIndex = 0
                    step = .littleWins
                } else {
                    step = .priorities
                    deepIndex = 0
                    if !didOpenPriorities {
                        priorityCategoryIDs.removeAll()
                        didOpenPriorities = true
                    }
                }
            }
        case .priorities:
            deepIndex = 0
            step = .littleWins
        case .littleWins:
            if let record = currentDeepRecord, addingFocus {
                commitFocus(record)
            }
            if deepIndex < deepCategoryIDs.count - 1 {
                deepIndex += 1
            } else {
                passionIndex = 0
                step = .passions
            }
        case .resources:
            passionIndex = 0
            step = .passions
        case .passions:
            if passionIndex < roleCategoryIDs.count - 1 {
                passionIndex += 1
            } else {
                if isAddSingleAreaMode {
                    finalizeAddedAreaAndDismiss()
                } else {
                    step = .summary
                }
            }
        default:
            break
        }
    }

    private func moveVisionForward(saveCurrent: Bool) {
        if saveCurrent, let record = currentVisionRecord {
            let text = (visionDrafts[record.category_id] ?? record.category_vision).trimmingCharacters(in: .whitespacesAndNewlines)
            updateVision(record: record, newText: text)
        }

        if visionIndex < orderedFulfillments.count - 1 {
            visionIndex += 1
        } else {
            purposeIndex = 0
            step = .purposeSweep
        }
    }

    private func movePurposeForward(saveCurrent: Bool) {
        if saveCurrent, let record = currentPurposeRecord {
            let text = (purposeDrafts[record.category_id] ?? record.category_purpose).trimmingCharacters(in: .whitespacesAndNewlines)
            updatePurpose(record: record, newText: text)
        }

        if purposeIndex < orderedFulfillments.count - 1 {
            purposeIndex += 1
        } else {
            roleIndex = 0
            step = .roles
        }
    }

    private func togglePriority(_ id: UUID) {
        if priorityCategoryIDs.contains(id) {
            priorityCategoryIDs.removeAll { $0 == id }
        } else {
            priorityCategoryIDs.append(id)
        }
        if !priorityCategoryIDs.isEmpty {
            highlightInvalid = false
            invalidCategoryIDs.removeAll()
            showValidationHint = false
        }
        persistDraftIfNeeded()
    }

    // MARK: - Data load & finalize

    private func loadFromPersistentData() {
        refreshFulfillmentSnapshot()
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        let categoriesFromFulfillment = sourceRows
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let categoriesFromLabels = isAddSingleAreaMode ? [] : planLabels
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let existingCategories = Array(Set(categoriesFromFulfillment + categoriesFromLabels))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if isAddSingleAreaMode {
            addModeInitialActiveCategoryKeys = Set(categoriesFromFulfillment.map { categoryKey($0) })
        }
        var diagnosticPrefillColorKeys: [String: String] = [:]
        if isAddSingleAreaMode {
            selectedCategoryNames = []
            customCategoryNames = existingCategories.filter { !fulfillmentStartSelectableDefaultCategories.contains($0) }
        } else {
            selectedCategoryNames = existingCategories
            customCategoryNames = existingCategories.filter { !fulfillmentStartSelectableDefaultCategories.contains($0) }
            diagnosticPrefillColorKeys = applyDiagnosticPrefillIfNeeded(existingCategories: existingCategories)
        }
        var map = FulfillmentCategoryTheme.persistedColorKeys()
        let cycleKeys = onboardingColorCycleKeys
        if !cycleKeys.isEmpty {
            for (idx, category) in availableCategoryNames.enumerated() {
                let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if let diagnosticKey = diagnosticPrefillColorKeys[trimmed] {
                    map[trimmed] = diagnosticKey
                    continue
                }
                // Preserve user-managed color assignments from AccountView.
                // Only assign a fallback color when none exists yet.
                if map[trimmed] == nil {
                    map[trimmed] = cycleKeys[idx % cycleKeys.count]
                }
            }
        }
        categoryColorKeys = map
        normalizeSelectedCategoryColorAssignments()

        visionDrafts = Dictionary(uniqueKeysWithValues: orderedFulfillments.map { ($0.category_id, $0.category_vision) })
        purposeDrafts = Dictionary(uniqueKeysWithValues: orderedFulfillments.map { ($0.category_id, $0.category_purpose) })
        let categoryIDs = Set(orderedFulfillments.map(\.category_id))
        draftRoles = roles
            .filter { categoryIDs.contains($0.category_id) }
            .map {
                DraftRoleRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    role: $0.role,
                    rank: $0.rank
                )
            }
        draftFoci = foci
            .filter { categoryIDs.contains($0.category_id) }
            .map {
                DraftFocusRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    activity: $0.activity,
                    rank: $0.rank
                )
            }
        draftResources = resources
            .filter { categoryIDs.contains($0.category_id) }
            .map {
                DraftResourceRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    resource: $0.resource,
                    rank: $0.rank
                )
            }
        draftPassionJoins = passionJoins
            .filter { categoryIDs.contains($0.category_id) }
            .map {
                DraftPassionJoinRow(
                    id: $0.id,
                    passionID: $0.passion_id,
                    categoryID: $0.category_id
                )
            }

        priorityCategoryIDs = priorityCategoryIDs.filter { id in
            orderedFulfillments.contains(where: { $0.category_id == id })
        }
        if isAddSingleAreaMode {
            priorityCategoryIDs = []
        }
        visionIndex = min(visionIndex, max(orderedFulfillments.count - 1, 0))
        purposeIndex = min(purposeIndex, max(orderedFulfillments.count - 1, 0))
        roleIndex = min(roleIndex, max(roleCategoryIDs.count - 1, 0))
        deepIndex = min(deepIndex, max(deepCategoryIDs.count - 1, 0))
        passionIndex = min(passionIndex, max(roleCategoryIDs.count - 1, 0))
    }

    private func applyDiagnosticPrefillIfNeeded(existingCategories: [String]) -> [String: String] {
        guard !isAddSingleAreaMode else { return [:] }
        guard existingCategories.isEmpty else { return [:] }
        guard selectedCategoryNames.isEmpty else { return [:] }
        guard let personalizationSnapshot = PersonalizationStore.cachedContextForCurrentUser()?.current else { return [:] }
        let diagnosticAreas = personalizationSnapshot.lifeAreasSelected
        guard !diagnosticAreas.isEmpty else { return [:] }
        let diagnosticColorKeys = personalizationSnapshot.lifeAreaColorKeys

        var preselected: [String] = []
        var custom = customCategoryNames
        var mappedColorByCategory: [String: String] = [:]
        for area in diagnosticAreas {
            let mapped = mappedFulfillmentCategoryName(fromDiagnosticArea: area)
            let trimmed = mapped.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let hasSelected = preselected.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
            if !hasSelected {
                preselected.append(trimmed)
            }

            let isDefault = fulfillmentStartSelectableDefaultCategories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
            let hasCustom = custom.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
            if !isDefault && !hasCustom {
                custom.append(trimmed)
            }

            if let colorKey = diagnosticColorKey(for: area, in: diagnosticColorKeys) {
                mappedColorByCategory[trimmed] = colorKey
            }
        }

        let limited = Array(preselected.prefix(7))
        guard !limited.isEmpty else { return [:] }
        selectedCategoryNames = limited
        customCategoryNames = custom
        return mappedColorByCategory.filter { category, _ in
            limited.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame })
        }
    }

    private func diagnosticColorKey(for area: String, in map: [String: String]) -> String? {
        let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let exact = map[trimmed] {
            return exact
        }
        return map.first(where: { $0.key.caseInsensitiveCompare(trimmed) == .orderedSame })?.value
    }

    private func mappedFulfillmentCategoryName(fromDiagnosticArea area: String) -> String {
        let normalized = categoryKey(area)
        switch normalized {
        case categoryKey("Health & Vitality"):
            return "Health & Energy"
        case categoryKey("Mind & Meaning"):
            return "Mindset & Resilience"
        case categoryKey("Home & Lifestyle"):
            return "Home & Life"
        case categoryKey("Community & Service"):
            return "Service & Impact"
        case categoryKey("Creativity & Fun"):
            return "Lifestyle & Experiences"
        default:
            return area
        }
    }

    private func normalizeSelectedCategoryColorAssignments() {
        guard !selectedCategoryNames.isEmpty else { return }
        var map = categoryColorKeys
        var used = Set<String>()
        for category in selectedCategoryNames {
            let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let preferred = map[trimmed]
                ?? FulfillmentCategoryTheme.defaultColorKeys()[trimmed]
                ?? rotatedColorKey(for: trimmed)
            let resolved = nextAvailableColorKey(preferred: preferred, unavailable: used)
            map[trimmed] = resolved
            used.insert(resolved)
        }
        categoryColorKeys = map
    }

    private func applyLoomAIPrefillIfAvailable() {
        guard isAddSingleAreaMode, let prefill = LoomAIFulfillmentAreaPrefillStore.take() else { return }

        let categoryName = prefill.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryName.isEmpty else { return }

        if !customCategoryNames.contains(where: { $0.caseInsensitiveCompare(categoryName) == .orderedSame }) &&
            !fulfillmentStartSelectableDefaultCategories.contains(where: { $0.caseInsensitiveCompare(categoryName) == .orderedSame }) {
            customCategoryNames.append(categoryName)
        }
        toggleCategorySelection(categoryName, forceSelected: true)
        assignDefaultColorIfNeeded(for: categoryName)

        refreshFulfillmentSnapshot()
        applyCategorySelectionToLiveDataIfNeeded()
        refreshFulfillmentSnapshot()

        guard let record = (fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot).first(where: {
            $0.category.caseInsensitiveCompare(categoryName) == .orderedSame
        }) else {
            return
        }

        if let mission = prefill.mission?.trimmingCharacters(in: .whitespacesAndNewlines), !mission.isEmpty {
            purposeDrafts[record.category_id] = mission
            if let idx = fulfillmentSnapshot.firstIndex(where: { $0.category_id == record.category_id }) {
                fulfillmentSnapshot[idx].category_purpose = mission
            }
        }

        if !prefill.identities.isEmpty {
            var existingRoleTexts = Set(draftRoles
                .filter { $0.categoryID == record.category_id }
                .map { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            var nextRank = (draftRoles.filter { $0.categoryID == record.category_id }.map(\.rank).max() ?? -1) + 1
            for identity in prefill.identities.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
                let key = identity.lowercased()
                guard !existingRoleTexts.contains(key) else { continue }
                draftRoles.append(.init(id: UUID(), categoryID: record.category_id, updatedAt: .now, role: identity, rank: nextRank))
                existingRoleTexts.insert(key)
                nextRank += 1
            }
        }

        if !prefill.littleWins.isEmpty {
            var existingFocusTexts = Set(draftFoci
                .filter { $0.categoryID == record.category_id }
                .map { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            var nextRank = (draftFoci.filter { $0.categoryID == record.category_id }.map(\.rank).max() ?? -1) + 1
            for littleWin in prefill.littleWins.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }).prefix(3) {
                let key = littleWin.lowercased()
                guard !existingFocusTexts.contains(key) else { continue }
                draftFoci.append(.init(id: UUID(), categoryID: record.category_id, updatedAt: .now, activity: littleWin, rank: nextRank))
                existingFocusTexts.insert(key)
                nextRank += 1
            }
        }

        if !prefill.connectedPassions.isEmpty {
            var passionsByKey = Dictionary(uniqueKeysWithValues: passions.map {
                ("\(displayEmotionLabel(for: $0.emotion).lowercased())|\($0.passion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())", $0)
            })
            let existingJoinPassionIDs = Set(draftPassionJoins.filter { $0.categoryID == record.category_id }.map(\.passionID))
            for raw in prefill.connectedPassions {
                let parsed = parsePrefillPassion(raw)
                guard let parsed else { continue }
                let key = "\(parsed.emotion.lowercased())|\(parsed.title.lowercased())"
                let passion: Passion
                if let existing = passionsByKey[key] {
                    passion = existing
                } else {
                    let created = Passion(date: .now, emotion: parsed.emotion.lowercased(), passion: parsed.title)
                    modelContext.insert(created)
                    passionsByKey[key] = created
                    passion = created
                }
                if !existingJoinPassionIDs.contains(passion.passion_id) &&
                    !draftPassionJoins.contains(where: { $0.categoryID == record.category_id && $0.passionID == passion.passion_id }) {
                    draftPassionJoins.append(.init(id: UUID(), passionID: passion.passion_id, categoryID: record.category_id))
                }
            }
        }

        if let idx = orderedFulfillments.firstIndex(where: { $0.category_id == record.category_id }) {
            visionIndex = idx
            purposeIndex = idx
        }
        if let idx = roleCategoryIDs.firstIndex(of: record.category_id) {
            roleIndex = idx
            passionIndex = idx
        }
        step = .visionSweep
    }

    private func parsePrefillPassion(_ raw: String) -> (emotion: String, title: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let emotions = ["love", "thrill", "vows", "hate"]
        if let colon = trimmed.firstIndex(of: ":") {
            let left = trimmed[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let right = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if emotions.contains(left), !right.isEmpty { return (left, right) }
        }
        return ("love", trimmed)
    }

    private func addCategory() {
        let trimmed = newCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingCategory = false
            newCategoryText = ""
            return
        }
        let duplicate = availableCategoryNames.contains { $0.lowercased() == trimmed.lowercased() }
        guard !duplicate else {
            triggerHint("Duplicate category name.")
            return
        }
        customCategoryNames.append(trimmed)
        toggleCategorySelection(trimmed, forceSelected: true)
        addingCategory = false
        newCategoryText = ""
        persistDraftIfNeeded()
    }

    private func deleteCategory(_ record: Fulfillment) {
        guard orderedFulfillments.count > 3 else {
            triggerHint("Keep at least 3 categories.")
            return
        }
        RecentlyDeletedStore.trash(record, in: modelContext)
        try? modelContext.save()
    }

    private func removeCategoryFromStepList(_ category: String) {
        if fulfillmentStartSelectableDefaultCategories.contains(category) {
            deletedDefaultCategoryNames.insert(category)
        } else {
            customCategoryNames.removeAll { $0.caseInsensitiveCompare(category) == .orderedSame }
        }
        selectedCategoryNames.removeAll { $0.caseInsensitiveCompare(category) == .orderedSame }
        categoryColorKeys.removeValue(forKey: category)
        applyCategorySelectionToLiveDataIfNeeded()
        persistDraftIfNeeded()
    }

    private func attemptRemoveCategoryFromStepList(_ category: String) {
        if hasOngoingUsage(in: category) {
            triggerHint("This category has an ongoing action plan, group, or outcome.")
            return
        }
        removeCategoryFromStepList(category)
    }

    private func restoreDeletedDefaultCategories() {
        let missing = missingDefaultCategories
        deletedDefaultCategoryNames = deletedDefaultCategoryNames.filter { deleted in
            !missing.contains(where: { $0.caseInsensitiveCompare(deleted) == .orderedSame })
        }
        let cycleKeys = onboardingColorCycleKeys
        if !cycleKeys.isEmpty {
            var map = categoryColorKeys
            for (idx, category) in fulfillmentStartSelectableDefaultCategories.enumerated() {
                map[category] = cycleKeys[idx % cycleKeys.count]
            }
            categoryColorKeys = map
        }
        for category in missing {
            assignDefaultColorIfNeeded(for: category)
        }
        persistDraftIfNeeded()
    }

    private func hasOngoingUsage(in category: String) -> Bool {
        let categoryTrimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryTrimmed.isEmpty else { return false }

        let activeWeeks = Set(
            activePlanStates
                .filter(\.isActive)
                .compactMap(\.weekStart)
                .map { Calendar.current.startOfDay(for: $0) }
        )
        let activeChunks = allPlannedChunks.filter {
            $0.category.caseInsensitiveCompare(categoryTrimmed) == .orderedSame &&
            activeWeeks.contains(Calendar.current.startOfDay(for: $0.weekStart))
        }
        if !activeChunks.isEmpty {
            return true
        }

        let activeChunkIDs = Set(activeChunks.map(\.id))
        if !activeChunkIDs.isEmpty && allPlannedActions.contains(where: { activeChunkIDs.contains($0.plannedChunkId) }) {
            return true
        }

        return allOutcomes.contains {
            $0.category.caseInsensitiveCompare(categoryTrimmed) == .orderedSame
        }
    }

    private func toggleCategorySelection(_ category: String, forceSelected: Bool? = nil) {
        let shouldSelect: Bool
        if let forceSelected {
            shouldSelect = forceSelected
        } else {
            shouldSelect = !selectedCategoryNames.contains(category)
        }

        if shouldSelect {
            if isAddSingleAreaMode {
                selectedCategoryNames = [category]
            } else {
                guard selectedCategoryNames.count < 7 else { return }
                if !selectedCategoryNames.contains(category) {
                    selectedCategoryNames.append(category)
                }
            }
            assignDefaultColorIfNeeded(for: category)
        } else {
            if hasOngoingUsage(in: category) {
                triggerHint("This category has an ongoing action plan, group, or outcome.")
                return
            }
            selectedCategoryNames.removeAll { $0.caseInsensitiveCompare(category) == .orderedSame }
        }
        applyCategorySelectionToLiveDataIfNeeded()
        persistDraftIfNeeded()
    }

    private func applyCategorySelectionToLiveDataIfNeeded() {
        guard !isAddSingleAreaMode else { return }
        guard !usesDraftPersistence else { return }
        insertSelectedCategoriesIntoLiveData()
        pruneUnselectedCategoriesFromLiveData()
        try? modelContext.save()
        refreshFulfillmentSnapshot()
    }

    private func insertSelectedCategoriesIntoLiveData() {
        let sourceRows = fulfillments
        for category in selectedCategoryNames {
            let exists = sourceRows.contains {
                categoryKey($0.category) == categoryKey(category)
            }
            guard !exists else { continue }
            modelContext.insert(
                Fulfillment(
                    category_id: UUID(),
                    updatedAt: Date(),
                    category: category,
                    category_identitiy: "",
                    category_vision: "",
                    category_purpose: ""
                )
            )
        }
    }

    private func pruneUnselectedCategoriesFromLiveData() {
        let selectedKeys = Set(
            selectedCategoryNames.map { categoryKey($0) }
        )
        let rowsToDelete = fulfillments.filter { !selectedKeys.contains(categoryKey($0.category)) }
        let unselectedCategoryNames = Set(
            (fulfillments.map(\.category) + planLabels.map(\.category))
                .filter { !selectedKeys.contains(categoryKey($0)) }
        )
        guard !rowsToDelete.isEmpty || !unselectedCategoryNames.isEmpty else { return }

        let idsToDelete = Set(rowsToDelete.map(\.category_id))
        for role in roles where idsToDelete.contains(role.category_id) {
            modelContext.delete(role)
        }
        for focus in foci where idsToDelete.contains(focus.category_id) {
            modelContext.delete(focus)
        }
        for resource in resources where idsToDelete.contains(resource.category_id) {
            modelContext.delete(resource)
        }
        for join in passionJoins where idsToDelete.contains(join.category_id) {
            modelContext.delete(join)
        }
        for label in planLabels where unselectedCategoryNames.contains(where: { $0.caseInsensitiveCompare(label.category) == .orderedSame }) {
            modelContext.delete(label)
        }
        for row in rowsToDelete {
            modelContext.delete(row)
        }
    }

    private func syncSelectedCategoriesIntoFulfillment() {
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        let sourceByKey = Dictionary(uniqueKeysWithValues: sourceRows.map { (categoryKey($0.category), $0) })
        let stagedRows: [Fulfillment] = selectedCategoryNames.map { category in
            let key = categoryKey(category)
            if let existing = sourceByKey[key] {
                return existing
            }
            return Fulfillment(
                category_id: UUID(),
                updatedAt: Date(),
                category: category,
                category_identitiy: "",
                category_vision: "",
                category_purpose: ""
            )
        }
        fulfillmentSnapshot = stagedRows

        visionDrafts = Dictionary(uniqueKeysWithValues: stagedRows.map { ($0.category_id, $0.category_vision) })
        purposeDrafts = Dictionary(uniqueKeysWithValues: stagedRows.map { ($0.category_id, $0.category_purpose) })
        visionIndex = min(visionIndex, max(orderedFulfillments.count - 1, 0))
        purposeIndex = min(purposeIndex, max(orderedFulfillments.count - 1, 0))
        roleIndex = min(roleIndex, max(roleCategoryIDs.count - 1, 0))
        deepIndex = min(deepIndex, max(deepCategoryIDs.count - 1, 0))
        passionIndex = min(passionIndex, max(roleCategoryIDs.count - 1, 0))
        persistDraftIfNeeded()
    }

    private func refreshFulfillmentSnapshot() {
        let descriptor = FetchDescriptor<Fulfillment>()
        if let rows = try? modelContext.fetch(descriptor) {
            fulfillmentSnapshot = rows
        }
    }

    private func persistDraftIfNeeded() {
        guard usesDraftPersistence, !didFinalizeOnboarding else { return }
        persistDraft()
    }

    private func persistDraft() {
        let rows = orderedFulfillments
        let rowIDs = Set(rows.map(\.category_id))
        let rolesRows = draftRoles.filter { rowIDs.contains($0.categoryID) }
        let fociRows = draftFoci.filter { rowIDs.contains($0.categoryID) }
        let resourcesRows = draftResources.filter { rowIDs.contains($0.categoryID) }
        let joinRows = draftPassionJoins.filter { rowIDs.contains($0.categoryID) }

        let draft = DraftState(
            stepRawValue: step.rawValue,
            visionIndex: visionIndex,
            purposeIndex: purposeIndex,
            deepIndex: deepIndex,
            passionIndex: passionIndex,
            priorityCategoryIDs: priorityCategoryIDs,
            selectedCategoryNames: selectedCategoryNames,
            customCategoryNames: customCategoryNames,
            deletedDefaultCategoryNames: Array(deletedDefaultCategoryNames),
            categoryColorKeys: categoryColorKeys,
            visionDrafts: Dictionary(uniqueKeysWithValues: visionDrafts.map { ($0.key.uuidString, $0.value) }),
            purposeDrafts: Dictionary(uniqueKeysWithValues: purposeDrafts.map { ($0.key.uuidString, $0.value) }),
            fulfillments: rows.map {
                DraftFulfillmentRow(
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    category: $0.category,
                    identity: $0.category_identitiy,
                    vision: $0.category_vision,
                    purpose: $0.category_purpose
                )
            },
            roles: rolesRows,
            foci: fociRows,
            resources: resourcesRows,
            passionJoins: joinRows
        )

        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftStorageKey)
    }

    private func restoreDraftIfAvailable() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.draftStorageKey),
              let draft = try? JSONDecoder().decode(DraftState.self, from: data) else {
            return false
        }
        fulfillmentSnapshot = draft.fulfillments.map {
            Fulfillment(
                category_id: $0.categoryID,
                updatedAt: $0.updatedAt,
                category: $0.category,
                category_identitiy: $0.identity,
                category_vision: $0.vision,
                category_purpose: $0.purpose
            )
        }

        selectedCategoryNames = draft.selectedCategoryNames
        customCategoryNames = draft.customCategoryNames
        deletedDefaultCategoryNames = Set(draft.deletedDefaultCategoryNames)
        // Preserve in-progress onboarding colors first, then fill any missing keys
        // from globally persisted preferences.
        var mergedColors = draft.categoryColorKeys
        for (category, key) in FulfillmentCategoryTheme.persistedColorKeys() where mergedColors[category] == nil {
            mergedColors[category] = key
        }
        categoryColorKeys = mergedColors
        priorityCategoryIDs = draft.priorityCategoryIDs
        draftRoles = draft.roles
        draftFoci = draft.foci
        draftResources = draft.resources
        draftPassionJoins = draft.passionJoins
        let restoredStep = Step(rawValue: draft.stepRawValue) ?? .intro
        visionIndex = max(0, draft.visionIndex)
        purposeIndex = max(0, draft.purposeIndex)
        deepIndex = max(0, draft.deepIndex)
        passionIndex = max(0, draft.passionIndex ?? 0)
        step = restoredStep
        visionDrafts = Dictionary(uniqueKeysWithValues: draft.visionDrafts.compactMap { entry -> (UUID, String)? in
            let (key, value) = entry
            guard let id = UUID(uuidString: key) else { return nil }
            return (id, value)
        })
        purposeDrafts = Dictionary(uniqueKeysWithValues: draft.purposeDrafts.compactMap { entry -> (UUID, String)? in
            let (key, value) = entry
            guard let id = UUID(uuidString: key) else { return nil }
            return (id, value)
        })
        return true
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftStorageKey)
    }

    private func assignDefaultColorIfNeeded(for category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var map = categoryColorKeys
        let preferred = map[trimmed]
            ?? FulfillmentCategoryTheme.defaultColorKeys()[trimmed]
            ?? rotatedColorKey(for: trimmed)
        let unavailable = unavailableColorKeysUsingMap(for: trimmed, map: map)
        let resolved = nextAvailableColorKey(preferred: preferred, unavailable: unavailable)
        map[trimmed] = resolved
        categoryColorKeys = map
    }

    private func unavailableColorKeysUsingMap(for category: String, map: [String: String]) -> Set<String> {
        let current = category.trimmingCharacters(in: .whitespacesAndNewlines)
        var keys = Set<String>()

        for otherCategory in selectedCategoryNames {
            let other = otherCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !other.isEmpty else { continue }
            guard other.caseInsensitiveCompare(current) != .orderedSame else { continue }
            let colorKey = map[other]
                ?? FulfillmentCategoryTheme.defaultColorKeys()[other]
                ?? rotatedColorKey(for: other)
            keys.insert(colorKey)
        }

        if isAddSingleAreaMode {
            keys.formUnion(activeCategoryColorKeys)
        }

        return keys
    }

    private func nextAvailableColorKey(preferred: String, unavailable: Set<String>) -> String {
        let paletteKeys = FulfillmentCategoryTheme.palette.map(\.key)
        guard !paletteKeys.isEmpty else { return "blue" }
        let preferredKey = paletteKeys.contains(preferred) ? preferred : (paletteKeys.first ?? "blue")
        let startIndex = paletteKeys.firstIndex(of: preferredKey) ?? 0
        for offset in 0..<paletteKeys.count {
            let candidate = paletteKeys[(startIndex + offset) % paletteKeys.count]
            if !unavailable.contains(candidate) {
                return candidate
            }
        }
        return preferredKey
    }

    private func applyColorSelection(for category: String, colorKey: String) {
        guard availableColorOptions(for: category).contains(where: { $0.key == colorKey }) else { return }
        var map = categoryColorKeys
        let resolvedBefore = map[category] ?? FulfillmentCategoryTheme.defaultColorKeys()[category] ?? "blue"
        if let other = map.first(where: { $0.key != category && $0.value == colorKey })?.key {
            map[other] = resolvedBefore
        }
        map[category] = colorKey
        categoryColorKeys = map
        persistDraftIfNeeded()
    }

    private func fulfillmentCategoryColor(for category: String) -> Color {
        let key = categoryColorKeys[category] ?? rotatedColorKey(for: category)
        return FulfillmentCategoryTheme.color(forKey: key)
    }

    private func rotatedColorKey(for category: String) -> String {
        let cycleKeys = onboardingColorCycleKeys
        guard !cycleKeys.isEmpty else { return "blue" }
        if let idx = availableCategoryNames.firstIndex(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
            return cycleKeys[idx % cycleKeys.count]
        }
        return cycleKeys.first ?? "blue"
    }

    private func finalizeAndContinue() {
        guard summaryCanComplete else {
            triggerHint("Complete required items before continuing.")
            return
        }

        commitStagedFulfillmentRowsToContext()
        FulfillmentCategoryTheme.persistColorKeys(categoryColorKeys)
        try? modelContext.save()
        didFinalizeOnboarding = true
        clearDraft()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: Notification.Name("open_fulfillment_after_onboarding"), object: nil)
        }
    }

    private func finalizeAddedAreaAndDismiss() {
        commitStagedFulfillmentRowsToContextAdditive()
        FulfillmentCategoryTheme.persistColorKeys(categoryColorKeys)
        try? modelContext.save()
        didFinalizeOnboarding = true
        dismiss()
    }

    private func commitStagedFulfillmentRowsToContextAdditive() {
        let stagedRows = orderedFulfillments
        let liveRows = (try? modelContext.fetch(FetchDescriptor<Fulfillment>())) ?? []
        let liveRoles = (try? modelContext.fetch(FetchDescriptor<FulfillmentRoles>())) ?? []
        let liveFoci = (try? modelContext.fetch(FetchDescriptor<FulfillmentFocus>())) ?? []
        let liveResources = (try? modelContext.fetch(FetchDescriptor<FulfillmentResources>())) ?? []
        let liveJoins = (try? modelContext.fetch(FetchDescriptor<PassionFulfillmentJoin>())) ?? []

        var resolvedCategoryIDByDraftID: [UUID: UUID] = [:]
        for staged in stagedRows {
            if let existing = liveRows.first(where: {
                $0.category_id == staged.category_id ||
                categoryKey($0.category) == categoryKey(staged.category)
            }) {
                existing.category = staged.category
                existing.category_identitiy = staged.category_identitiy
                existing.category_vision = staged.category_vision
                existing.category_purpose = staged.category_purpose
                existing.updatedAt = Date()
                resolvedCategoryIDByDraftID[staged.category_id] = existing.category_id
            } else {
                resolvedCategoryIDByDraftID[staged.category_id] = staged.category_id
                modelContext.insert(
                    Fulfillment(
                        category_id: staged.category_id,
                        updatedAt: staged.updatedAt,
                        category: staged.category,
                        category_identitiy: staged.category_identitiy,
                        category_vision: staged.category_vision,
                        category_purpose: staged.category_purpose
                    )
                )
            }
        }

        let keptIDs = Set(resolvedCategoryIDByDraftID.values)
        for role in liveRoles where keptIDs.contains(role.category_id) { modelContext.delete(role) }
        for focus in liveFoci where keptIDs.contains(focus.category_id) { modelContext.delete(focus) }
        for resource in liveResources where keptIDs.contains(resource.category_id) { modelContext.delete(resource) }
        for join in liveJoins where keptIDs.contains(join.category_id) { modelContext.delete(join) }

        for row in draftRoles {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(FulfillmentRoles(id: row.id, category_id: categoryID, updatedAt: row.updatedAt, role: row.role, rank: row.rank))
        }
        for row in draftFoci {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(FulfillmentFocus(id: row.id, category_id: categoryID, updatedAt: row.updatedAt, activity: row.activity, rank: row.rank))
        }
        for row in draftResources {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(FulfillmentResources(id: row.id, category_id: categoryID, updatedAt: row.updatedAt, resource: row.resource, rank: row.rank))
        }
        for row in draftPassionJoins {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(PassionFulfillmentJoin(id: row.id, passion_id: row.passionID, category_id: categoryID))
        }
    }

    private func commitStagedFulfillmentRowsToContext() {
        let stagedRows = orderedFulfillments
        let selectedKeys = Set(selectedCategoryNames.map { categoryKey($0) })
        let liveRows = (try? modelContext.fetch(FetchDescriptor<Fulfillment>())) ?? []
        let liveRoles = (try? modelContext.fetch(FetchDescriptor<FulfillmentRoles>())) ?? []
        let liveFoci = (try? modelContext.fetch(FetchDescriptor<FulfillmentFocus>())) ?? []
        let liveResources = (try? modelContext.fetch(FetchDescriptor<FulfillmentResources>())) ?? []
        let liveJoins = (try? modelContext.fetch(FetchDescriptor<PassionFulfillmentJoin>())) ?? []

        // Remove categories not included in this onboarding result.
        let rowsToDelete = liveRows.filter { !selectedKeys.contains(categoryKey($0.category)) }
        if !rowsToDelete.isEmpty {
            let idsToDelete = Set(rowsToDelete.map(\.category_id))
            for role in liveRoles where idsToDelete.contains(role.category_id) {
                modelContext.delete(role)
            }
            for focus in liveFoci where idsToDelete.contains(focus.category_id) {
                modelContext.delete(focus)
            }
            for resource in liveResources where idsToDelete.contains(resource.category_id) {
                modelContext.delete(resource)
            }
            for join in liveJoins where idsToDelete.contains(join.category_id) {
                modelContext.delete(join)
            }
            for row in rowsToDelete {
                modelContext.delete(row)
            }
        }

        var resolvedCategoryIDByDraftID: [UUID: UUID] = [:]
        for staged in stagedRows {
            if let existing = liveRows.first(where: {
                $0.category_id == staged.category_id
                || categoryKey($0.category) == categoryKey(staged.category)
            }) {
                existing.category = staged.category
                existing.category_identitiy = staged.category_identitiy
                existing.category_vision = staged.category_vision
                existing.category_purpose = staged.category_purpose
                existing.updatedAt = Date()
                resolvedCategoryIDByDraftID[staged.category_id] = existing.category_id
            } else {
                resolvedCategoryIDByDraftID[staged.category_id] = staged.category_id
                modelContext.insert(
                    Fulfillment(
                        category_id: staged.category_id,
                        updatedAt: staged.updatedAt,
                        category: staged.category,
                        category_identitiy: staged.category_identitiy,
                        category_vision: staged.category_vision,
                        category_purpose: staged.category_purpose
                    )
                )
            }
        }

        let keptIDs = Set(resolvedCategoryIDByDraftID.values)
        for role in liveRoles where keptIDs.contains(role.category_id) {
            modelContext.delete(role)
        }
        for focus in liveFoci where keptIDs.contains(focus.category_id) {
            modelContext.delete(focus)
        }
        for resource in liveResources where keptIDs.contains(resource.category_id) {
            modelContext.delete(resource)
        }
        for join in liveJoins where keptIDs.contains(join.category_id) {
            modelContext.delete(join)
        }

        for row in draftRoles {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(
                FulfillmentRoles(
                    id: row.id,
                    category_id: categoryID,
                    updatedAt: row.updatedAt,
                    role: row.role,
                    rank: row.rank
                )
            )
        }
        for row in draftFoci {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(
                FulfillmentFocus(
                    id: row.id,
                    category_id: categoryID,
                    updatedAt: row.updatedAt,
                    activity: row.activity,
                    rank: row.rank
                )
            )
        }
        for row in draftResources {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(
                FulfillmentResources(
                    id: row.id,
                    category_id: categoryID,
                    updatedAt: row.updatedAt,
                    resource: row.resource,
                    rank: row.rank
                )
            )
        }
        for row in draftPassionJoins {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(
                PassionFulfillmentJoin(
                    id: row.id,
                    passion_id: row.passionID,
                    category_id: categoryID
                )
            )
        }
    }

    // MARK: - Validation feedback

    private func triggerValidationFeedback() {
        highlightInvalid = true
        invalidCategoryIDs = []

        switch step {
        case .createCategories:
            validationHintText = hasCreateCategoriesColorConflict
                ? "Each color can only be used once."
                : (isAddSingleAreaMode ? "Select 1 category to continue." : "Create at least 3 life categories.")
        case .visionSweep:
            validationHintText = "Add a vision to continue."
            if let record = currentVisionRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .purposeSweep:
            validationHintText = "Add a mission to continue."
            if let record = currentPurposeRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .roles:
            validationHintText = "List 1 or more identities to continue."
            if let record = currentRoleRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .priorities:
            validationHintText = "Choose 1 or more areas than need increased focus."
        case .littleWins:
            validationHintText = "List 1 or more small wins to continue."
            if let record = currentDeepRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .resources:
            validationHintText = "Please continue."
        case .passions:
            validationHintText = "Connect at least 1 passion to continue."
            if let record = currentPassionRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        default:
            validationHintText = "Please complete required items."
        }

        triggerHint(validationHintText)
    }

    private func triggerHint(_ text: String) {
        hintWorkItem?.cancel()
        validationHintText = text
        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.15)) {
                showValidationHint = false
                highlightInvalid = false
                invalidCategoryIDs.removeAll()
            }
        }
        hintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    // MARK: - Persistence (mirrors FulfillmentView)

    private func updateVision(record: Fulfillment, newText: String) {
        guard record.category_vision != newText else { return }
        record.category_vision = newText
        record.updatedAt = Date()
        persistDraftIfNeeded()
    }

    private func updatePurpose(record: Fulfillment, newText: String) {
        guard record.category_purpose != newText else { return }
        record.category_purpose = newText
        record.updatedAt = Date()
        persistDraftIfNeeded()
    }

    private func getRoles(for f: Fulfillment) -> [DraftRoleRow] {
        draftRoles.filter { $0.categoryID == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addRole(text: String, record: Fulfillment) {
        guard !text.isEmpty else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard getRoles(for: record).count < 3 else {
            triggerHint("You can add up to 3 roles.")
            return
        }
        guard !roleExists(trimmed) else {
            triggerHint("Duplicate role is already entered.")
            return
        }
        let nextRank = (getRoles(for: record).map(\.rank).max() ?? 0) + 1
        draftRoles.append(
            DraftRoleRow(
                id: UUID(),
                categoryID: record.category_id,
                updatedAt: Date(),
                role: trimmed,
                rank: nextRank
            )
        )
        if nextRank == 1 {
            record.category_identitiy = text
            record.updatedAt = Date()
        }
        persistDraftIfNeeded()
    }

    private func roleExists(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return draftRoles.contains { role in
            role.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    private func deleteRoles(at offsets: IndexSet, record: Fulfillment) {
        let list = getRoles(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
            let r = list[idx]
            draftRoles.removeAll { $0.id == r.id }
        }
        persistDraftIfNeeded()
    }

    private func getFoci(for f: Fulfillment) -> [DraftFocusRow] {
        draftFoci.filter { $0.categoryID == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func presentLittleWinsAdvancedSheet(for record: Fulfillment) {
        if addingFocus {
            commitFocus(record)
        } else {
            focusedField = nil
        }
        stageDraftLittleWinsForAdvancedEditor(categoryID: record.category_id)
        littleWinsAdvancedCategoryID = record.category_id
        isPresentingLittleWinsAdvancedSheet = true
    }

    private func handleLittleWinsAdvancedSheetDismiss() {
        guard let categoryID = littleWinsAdvancedCategoryID else { return }
        mergeAdvancedLittleWinsFromModelIntoDraft(categoryID: categoryID)
        littleWinsAdvancedCategoryID = nil
    }

    private func stageDraftLittleWinsForAdvancedEditor(categoryID: UUID) {
        let draftRows = draftFoci
            .filter { $0.categoryID == categoryID }
            .sorted { $0.rank < $1.rank }
        let liveRows = foci.filter { $0.category_id == categoryID }
        let draftIDs = Set(draftRows.map(\.id))
        var liveByID = Dictionary(uniqueKeysWithValues: liveRows.map { ($0.id, $0) })

        for live in liveRows where !draftIDs.contains(live.id) {
            modelContext.delete(live)
        }

        for row in draftRows {
            if let live = liveByID[row.id] {
                live.activity = row.activity
                live.rank = row.rank
                live.updatedAt = row.updatedAt
            } else {
                modelContext.insert(
                    FulfillmentFocus(
                        id: row.id,
                        category_id: row.categoryID,
                        updatedAt: row.updatedAt,
                        activity: row.activity,
                        rank: row.rank
                    )
                )
            }
            liveByID[row.id] = nil
        }
    }

    private func mergeAdvancedLittleWinsFromModelIntoDraft(categoryID: UUID) {
        let mergedRows = foci
            .filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
            .map {
                DraftFocusRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    activity: $0.activity,
                    rank: $0.rank
                )
            }

        draftFoci.removeAll { $0.categoryID == categoryID }
        draftFoci.append(contentsOf: mergedRows)
        persistDraftIfNeeded()
    }

    private func addFocus(text: String, record: Fulfillment) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard getFoci(for: record).count < 3 else {
            triggerHint("You can add up to 3 little wins.")
            return
        }
        guard !focusExists(trimmed) else {
            triggerHint("Duplicate little win is already entered.")
            return
        }
        let nextRank = (getFoci(for: record).map(\.rank).max() ?? 0) + 1
        draftFoci.append(
            DraftFocusRow(
                id: UUID(),
                categoryID: record.category_id,
                updatedAt: Date(),
                activity: trimmed,
                rank: nextRank
            )
        )
        persistDraftIfNeeded()
    }

    private func focusExists(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return draftFoci.contains { row in
            row.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    private func deleteFoci(at offsets: IndexSet, record: Fulfillment) {
        let list = getFoci(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
            let f = list[idx]
            draftFoci.removeAll { $0.id == f.id }
        }
        persistDraftIfNeeded()
    }

    private func getResources(for f: Fulfillment) -> [DraftResourceRow] {
        draftResources.filter { $0.categoryID == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addResource(text: String, record: Fulfillment) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard getResources(for: record).count < 3 else {
            triggerHint("You can add up to 3 resources.")
            return
        }
        guard !resourceExists(trimmed) else {
            triggerHint("Duplicate resource is already entered.")
            return
        }
        let nextRank = (getResources(for: record).map(\.rank).max() ?? 0) + 1
        draftResources.append(
            DraftResourceRow(
                id: UUID(),
                categoryID: record.category_id,
                updatedAt: Date(),
                resource: trimmed,
                rank: nextRank
            )
        )
        persistDraftIfNeeded()
    }

    private func resourceExists(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return draftResources.contains { row in
            row.resource.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    private func deleteResources(at offsets: IndexSet, record: Fulfillment) {
        let list = getResources(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
            let r = list[idx]
            draftResources.removeAll { $0.id == r.id }
        }
        persistDraftIfNeeded()
    }

    private func selectedPassionIDs(for categoryID: UUID) -> Set<UUID> {
        Set(
            draftPassionJoins
                .filter { $0.categoryID == categoryID }
                .map(\.passionID)
        )
    }

    private func passionSelectionCount(for passionID: UUID) -> Int {
        let validCategoryIDs = Set(orderedFulfillments.map(\.category_id))
        return Set(
            draftPassionJoins
                .filter { $0.passionID == passionID && validCategoryIDs.contains($0.categoryID) }
                .map(\.categoryID)
        ).count
    }

    private func selectedPassions(for categoryID: UUID) -> [Passion] {
        let ids = selectedPassionIDs(for: categoryID)
        return passions.filter { ids.contains($0.passion_id) }
    }

    private func displayEmotionLabel(for raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "just": return "Hate"
        case "vows": return "Vow"
        default: return raw.capitalized
        }
    }

    private func togglePassion(_ passion: Passion, for categoryID: UUID) {
        let existing = draftPassionJoins.first {
            $0.passionID == passion.passion_id && $0.categoryID == categoryID
        }

        if let existing {
            draftPassionJoins.removeAll { $0.id == existing.id }
        } else {
            draftPassionJoins.append(
                DraftPassionJoinRow(
                    id: UUID(),
                    passionID: passion.passion_id,
                    categoryID: categoryID
                )
            )
        }
        persistDraftIfNeeded()
    }

    // MARK: - Inline commit helpers

    private func commitRole(_ record: Fulfillment) {
        let trimmed = roleEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingRole = false
            roleEntry = ""
            focusedField = nil
            return
        }
        addRole(text: trimmed, record: record)
        addingRole = false
        roleEntry = ""
        focusedField = nil
    }

    private func commitFocus(_ record: Fulfillment) {
        let trimmed = focusEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingFocus = false
            focusEntry = ""
            focusedField = nil
            return
        }
        addFocus(text: trimmed, record: record)
        addingFocus = false
        focusEntry = ""
        focusedField = nil
    }

    private func commitResource(_ record: Fulfillment) {
        let trimmed = resourceEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingResource = false
            resourceEntry = ""
            focusedField = nil
            return
        }
        addResource(text: trimmed, record: record)
        addingResource = false
        resourceEntry = ""
        focusedField = nil
    }
}

struct FulfillmentIntroRouteLinesView: View {
    var body: some View {
        FulfillmentIntroRouteLinesCanvas()
    }
}

#Preview {
    NavigationStack {
        FulfillmentStartView()
    }
}

private struct FulfillmentStartColorPickerSheet: View {
    let category: String
    let currentColorKey: String
    let options: [FulfillmentCategoryTheme.PaletteOption]
    let showsCloseButton: Bool
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.key) { option in
                    Button {
                        onSelect(option.key)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(option.color)
                                .frame(width: 22, height: 22)
                            Text(option.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if option.key == currentColorKey {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }
}

private extension FulfillmentStartView {
    private var shouldShowMissionAutoWriteControls: Bool {
        guard step == .purposeSweep, let record = currentPurposeRecord else { return false }
        return isSelectableDefaultCategory(record.category)
    }

    private var shouldShowIdentityAutoWriteControls: Bool {
        guard step == .roles, let record = currentRoleRecord else { return false }
        return isSelectableDefaultCategory(record.category)
    }

    private var shouldShowLittleWinAutoWriteControls: Bool {
        guard step == .littleWins, let record = currentDeepRecord else { return false }
        return isSelectableDefaultCategory(record.category)
    }

    private var autoWriteGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.15, green: 0.83, blue: 0.95),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.80, green: 0.38, blue: 0.78),
                Color(red: 0.98, green: 0.36, blue: 0.58),
                Color(red: 0.75, green: 0.42, blue: 0.74),
                Color(red: 0.22, green: 0.47, blue: 1.0)
            ],
            center: .center,
            angle: .degrees(autoWriteOutlineAngle)
        )
    }

    private var autoWriteSuggestionCardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.98, green: 0.36, blue: 0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func autoWriteSuggestionPrimaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return .white }
        return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private func autoWriteSuggestionSecondaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return Color.white.opacity(0.86) }
        return colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.62)
    }

    private func autoWriteSuggestionBackgroundFill(isApplied: Bool) -> AnyShapeStyle {
        if isApplied {
            if colorScheme == .dark {
                return AnyShapeStyle(autoWriteSuggestionCardFill.opacity(0.34))
            } else {
                return AnyShapeStyle(Color(red: 0.90, green: 0.97, blue: 0.92))
            }
        }
        return AnyShapeStyle(autoWriteSuggestionCardFill.opacity(0.92))
    }

    private func autoWriteSuggestionBorderColor(isApplied: Bool) -> Color {
        if isApplied {
            return colorScheme == .dark ? Color.white.opacity(0.18) : Color.green.opacity(0.30)
        }
        return Color.white.opacity(0.24)
    }

    @ViewBuilder
    private var missionAutoWriteControls: some View {
        if let record = currentPurposeRecord {
            let isLoading = autoWritingMissionCategoryID == record.category_id

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    guard !isLoading else { return }
                    Task { await requestAutoWriteMissionSuggestions(for: record, forceRefresh: true) }
                } label: {
                    HStack(spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .rotation3DEffect(
                                .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                                axis: (x: 1, y: 0, z: 0)
                            )
                        Text("AutoWrite")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(autoWriteGradient)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(.systemGroupedBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(autoWriteGradient, lineWidth: 2.25)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)
                .onAppear {
                    guard autoWriteOutlineAngle == 0 else { return }
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        autoWriteOutlineAngle = 360
                    }
                }
                .onChange(of: isLoading, initial: false) { _, newValue in
                    setAutoWriteLoadingAnimation(newValue)
                }
            }
        }
    }

    @ViewBuilder
    private var identityAutoWriteControls: some View {
        if let record = currentRoleRecord {
            let isLoading = autoWritingIdentityCategoryID == record.category_id

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    guard !isLoading else { return }
                    Task { await requestAutoWriteIdentitySuggestions(for: record, forceRefresh: true) }
                } label: {
                    HStack(spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .rotation3DEffect(
                                .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                                axis: (x: 1, y: 0, z: 0)
                            )
                        Text("AutoWrite")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(autoWriteGradient)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(.systemGroupedBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(autoWriteGradient, lineWidth: 2.25)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)
                .onAppear {
                    guard autoWriteOutlineAngle == 0 else { return }
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        autoWriteOutlineAngle = 360
                    }
                }
                .onChange(of: isLoading, initial: false) { _, newValue in
                    setAutoWriteLoadingAnimation(newValue)
                }
            }
        }
    }

    @ViewBuilder
    private var littleWinAutoWriteControls: some View {
        if let record = currentDeepRecord {
            let isLoading = autoWritingLittleWinCategoryID == record.category_id

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    guard !isLoading else { return }
                    Task { await requestAutoWriteLittleWinSuggestions(for: record, forceRefresh: true) }
                } label: {
                    HStack(spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .rotation3DEffect(
                                .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                                axis: (x: 1, y: 0, z: 0)
                            )
                        Text("AutoWrite")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(autoWriteGradient)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(.systemGroupedBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(autoWriteGradient, lineWidth: 2.25)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)
                .onAppear {
                    guard autoWriteOutlineAngle == 0 else { return }
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        autoWriteOutlineAngle = 360
                    }
                }
                .onChange(of: isLoading, initial: false) { _, newValue in
                    setAutoWriteLoadingAnimation(newValue)
                }
            }
        }
    }

    private func setAutoWriteLoadingAnimation(_ isLoading: Bool) {
        if isLoading {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimating = false
            autoWriteIconAnimationTask = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        autoWriteIconAnimating.toggle()
                    }
                    try? await Task.sleep(for: .milliseconds(550))
                }
            }
        } else {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                autoWriteIconAnimating = false
            }
        }
    }
}
