#encoding: utf-8

if StatisticIndex.count == 0
  StatisticIndex.create!([
     {id:1, es_type_key:'subscription', label:I18n.t('statistics.subscriptions')},
     {id:2, es_type_key:'machine', label:I18n.t('statistics.machines_hours')},
     {id:3, es_type_key:'training', label:I18n.t('statistics.trainings')},
     {id:4, es_type_key:'event', label:I18n.t('statistics.events')},
     {id:5, es_type_key:'account', label:I18n.t('statistics.registrations'), ca: false},
     {id:6, es_type_key:'project', label:I18n.t('statistics.projects'), ca: false},
     {id:7, es_type_key:'user', label:I18n.t('statistics.users'), table: false, ca: false}
  ])
  connection = ActiveRecord::Base.connection
  if connection.instance_values['config'][:adapter] == 'postgresql'
    connection.execute("SELECT setval('statistic_indices_id_seq', 7);")
  end
end

if StatisticField.count == 0
  StatisticField.create!([
    # available data_types : index, number, date, text, list
    {key:'trainingId', label:I18n.t('statistics.training_id'), statistic_index_id: 3, data_type: 'index'},
    {key:'trainingDate', label:I18n.t('statistics.training_date'), statistic_index_id: 3, data_type: 'date'},
    {key:'eventId', label:I18n.t('statistics.event_id'), statistic_index_id: 4, data_type: 'index'},
    {key:'eventDate', label:I18n.t('statistics.event_date'), statistic_index_id: 4, data_type: 'date'},
    {key:'themes', label:I18n.t('statistics.themes'), statistic_index_id: 6, data_type: 'list'},
    {key:'components', label:I18n.t('statistics.components'), statistic_index_id: 6, data_type: 'list'},
    {key:'machines', label:I18n.t('statistics.machines'), statistic_index_id: 6, data_type: 'list'},
    {key:'name', label:I18n.t('statistics.event_name'), statistic_index_id: 4, data_type: 'text'},
    {key:'userId', label:I18n.t('statistics.user_id'), statistic_index_id: 7, data_type: 'index'},
    {key:'eventTheme', label:I18n.t('statistics.event_theme'), statistic_index_id: 4, data_type: 'text'},
    {key:'ageRange', label:I18n.t('statistics.age_range'), statistic_index_id: 4, data_type: 'text'}
  ])
end

unless StatisticField.find_by(key:'groupName').try(:label)
  field = StatisticField.find_or_initialize_by(key: 'groupName')
  field.label = 'Groupe'
  field.statistic_index_id = 1
  field.data_type = 'text'
  field.save!
end

if StatisticType.count == 0
  StatisticType.create!([
    {statistic_index_id: 2, key: 'booking', label:I18n.t('statistics.bookings'), graph: true, simple: true},
    {statistic_index_id: 2, key: 'hour', label:I18n.t('statistics.hours_number'), graph: true, simple: false},
    {statistic_index_id: 3, key: 'booking', label:I18n.t('statistics.bookings'), graph: false, simple: true},
    {statistic_index_id: 3, key: 'hour', label:I18n.t('statistics.hours_number'), graph: false, simple: false},
    {statistic_index_id: 4, key: 'booking', label:I18n.t('statistics.tickets_number'), graph: false, simple: false},
    {statistic_index_id: 4, key: 'hour', label:I18n.t('statistics.hours_number'), graph: false, simple: false},
    {statistic_index_id: 5, key: 'member', label:I18n.t('statistics.users'), graph: true, simple: true},
    {statistic_index_id: 6, key: 'project', label:I18n.t('statistics.projects'), graph: false, simple: true},
    {statistic_index_id: 7, key: 'revenue', label:I18n.t('statistics.revenue'), graph: false, simple: false}
  ])
end

if StatisticSubType.count == 0
  StatisticSubType.create!([
    {key: 'created', label:I18n.t('statistics.account_creation'), statistic_types: StatisticIndex.find_by(es_type_key: 'account').statistic_types},
    {key: 'published', label:I18n.t('statistics.project_publication'), statistic_types: StatisticIndex.find_by(es_type_key: 'project').statistic_types}
  ])
end

if StatisticGraph.count == 0
  StatisticGraph.create!([
    {statistic_index_id:1, chart_type:'stackedAreaChart', limit:0},
    {statistic_index_id:2, chart_type:'stackedAreaChart', limit:0},
    {statistic_index_id:3, chart_type:'discreteBarChart', limit:10},
    {statistic_index_id:4, chart_type:'discreteBarChart', limit:10},
    {statistic_index_id:5, chart_type:'lineChart', limit:0},
    {statistic_index_id:7, chart_type:'discreteBarChart', limit:10}
  ])
end

if Group.count == 0
  Group.create!([
    {name: 'standard, association', slug: 'standard'},
    {name: "étudiant, - de 25 ans, enseignant, demandeur d'emploi", slug: 'student'},
    {name: 'artisan, commerçant, chercheur, auto-entrepreneur', slug: 'merchant'},
    {name: 'PME, PMI, SARL, SA', slug: 'business'}
  ])
end

# Create the admin if it does not exist yet
if User.find_by(email: Rails.application.secrets.admin_email).nil?
    admin = User.new(username: 'admin', email: Rails.application.secrets.admin_email, password: Rails.application.secrets.admin_password, password_confirmation: Rails.application.secrets.admin_password, group_id: Group.first.id, profile_attributes: {first_name: 'admin', last_name: 'admin', gender: true, phone: '0123456789', birthday: Time.now})
    admin.add_role 'admin'
    admin.save!
end

if Component.count == 0
  Component.create!([
    {name: 'Silicone'},
    {name: 'Vinyle'},
    {name: 'Bois Contre plaqué'},
    {name: 'Bois Medium'},
    {name: 'Plexi / PMMA'},
    {name: 'Flex'},
    {name: 'Vinyle'},
    {name: 'Parafine'},
    {name: 'Fibre de verre'},
    {name: 'Résine'}
  ])
end

if Licence.count == 0
  Licence.create!([
    {name: 'Attribution (BY)', description: 'Le titulaire des droits autorise toute exploitation de l’œuvre, y compris à des fins commerciales, ainsi que la création d’œuvres dérivées, dont la distribution est également autorisé sans restriction, à condition de l’attribuer à son l’auteur en citant son nom. Cette licence est recommandée pour la diffusion et l’utilisation maximale des œuvres.'},
    {name: 'Attribution + Pas de modification (BY ND)', description: 'Le titulaire des droits autorise toute utilisation de l’œuvre originale (y compris à des fins commerciales), mais n’autorise pas la création d’œuvres dérivées.'},
    {name: "Attribution + Pas d'Utilisation Commerciale + Pas de Modification (BY NC ND)", description: 'Le titulaire des droits autorise l’utilisation de l’œuvre originale à des fins non commerciales, mais n’autorise pas la création d’œuvres dérivés.'},
    {name: "Attribution + Pas d'Utilisation Commerciale (BY NC)", description: 'Le titulaire des droits autorise l’exploitation de l’œuvre, ainsi que la création d’œuvres dérivées, à condition qu’il ne s’agisse pas d’une utilisation commerciale (les utilisations commerciales restant soumises à son autorisation).'},
    {name: "Attribution + Pas d'Utilisation Commerciale + Partage dans les mêmes conditions (BY NC SA)", description: 'Le titulaire des droits autorise l’exploitation de l’œuvre originale à des fins non commerciales, ainsi que la création d’œuvres dérivées, à condition qu’elles soient distribuées sous une licence identique à celle qui régit l’œuvre originale.'},
    {name: 'Attribution + Partage dans les mêmes conditions (BY SA)', description: 'Le titulaire des droits autorise toute utilisation de l’œuvre originale (y compris à des fins commerciales) ainsi que la création d’œuvres dérivées, à condition qu’elles soient distribuées sous une licence identique à celle qui régit l’œuvre originale. Cette licence est souvent comparée aux licences « copyleft » des logiciels libres. C’est la licence utilisée par Wikipedia.'}
  ])
end

if Theme.count == 0
  Theme.create!([
    {name: 'Vie quotidienne'},
    {name: 'Robotique'},
    {name: 'Arduine'},
    {name: 'Capteurs'},
    {name: 'Musique'},
    {name: 'Sport'},
    {name: 'Autre'}
  ])
end

if Training.count == 0
  Training.create!([
    {name: 'Formation Imprimante 3D', description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.'},
    {name: 'Formation Laser / Vinyle', description: 'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.'},
    {name: 'Formation Petite fraiseuse numerique', description: 'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.'},
    {name: 'Formation Shopbot Grande Fraiseuse', description: 'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'},
    {name: 'Formation logiciel 2D', description: 'Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.'}
  ])

  TrainingsPricing.all.each do |p|
    p.update_columns(amount: (rand * 50 + 5).floor * 100)
  end
end

if Machine.count == 0
  Machine.create!([
    {name: 'Découpeuse laser', description: "Préparation à l'utilisation de l'EPILOG Legend 36EXT\r\nInformations générales    \r\n      Pour la découpe, il suffit d'apporter votre fichier vectorisé type illustrator, svg ou dxf avec des \"lignes de coupe\" d'une épaisseur inférieur à 0,01 mm et la machine s'occupera du reste!\r\n     La gravure est basée sur le spectre noir et blanc. Les nuances sont obtenues par différentes profondeurs de gravure correspondant aux niveaux de gris de votre image. Il suffit pour cela d'apporter une image scannée ou un fichier photo en noir et blanc pour pouvoir reproduire celle-ci sur votre support! \r\nQuels types de matériaux pouvons nous graver/découper?\r\n     Du bois au tissu, du plexiglass au cuir, cette machine permet de découper et graver la plupart des matériaux sauf les métaux. La gravure est néanmoins possible sur les métaux recouverts d'une couche de peinture ou les aluminiums anodisés. \r\n        Concernant l'épaisseur des matériaux découpés, il est préférable de ne pas dépasser 5 mm pour le bois et 6 mm pour le plexiglass.\r\n", spec: "Puissance: 40W\r\nSurface de travail: 914x609 mm \r\nEpaisseur maximale de la matière: 305mm\r\nSource laser: tube laser type CO2\r\nContrôles de vitesse et de puissance: ces deux paramètres sont ajustables en fonction du matériau (de 1% à 100%) .\r\n", slug: 'decoupeuse-laser'},
    {name: 'Découpeuse vinyle', description: "Préparation à l'utilisation de la Roland CAMM-1 GX24\r\nInformations générales        \r\n     Envie de réaliser un tee shirt personnalisé ? Un sticker à l'effigie votre groupe préféré? Un masque pour la réalisation d'un circuit imprimé? Pour cela, il suffit simplement de venir avec votre fichier vectorisé (ne pas oublier de vectoriser les textes) type illustrator svg ou dxf.\r\n \r\nMatériaux utilisés:\r\n    Cette machine permet de découper principalement du vinyle,vinyle réfléchissant, flex.\r\n", spec: "Largeurs de support acceptées: de 50 mm à 700 mm\r\nVitesse de découpe: 50 cm/sec\r\nRésolution mécanique: 0,0125 mm/pas\r\n", slug: 'decoupeuse-vinyle'},
    {name: 'Shopbot / Grande fraiseuse', description: "La fraiseuse numérique ShopBot PRS standard\r\nInformations générales\r\nCette machine est un fraiseuse 3 axes idéale pour l'usinage de pièces de grandes dimensions. De la réalisation d'une chaise ou d'un meuble jusqu'à la construction d'une maison ou d'un assemblage immense, le ShopBot ouvre de nombreuses portes à votre imagination! \r\nMatériaux usinables\r\nLes principaux matériaux usinables sont le bois, le plastique, le laiton et bien d'autres.\r\nCette machine n'usine pas les métaux.\r\n", spec: "Surface maximale de travail: 2440x1220x150 (Z) mm\r\nLogiciel utilisé: Partworks 2D & 3D\r\nRésolution mécanique: 0,015 mm\r\nPrécision de la position: +/- 0,127mm\r\nFormats acceptés: DXF, STL \r\n", slug: 'shopbot-grande-fraiseuse'},
    {name: 'Imprimante 3D', description: "L'utimaker est une imprimante 3D  low cost utilisant une technologie FFF (Fused Filament Fabrication) avec extrusion thermoplastique.\r\nC'est une machine idéale pour réaliser rapidement des prototypes 3D dans des couleurs différentes.\r\n", spec: "Surface maximale de travail: 210x210x220mm \r\nRésolution méchanique: 0,02 mm \r\nPrécision de position: +/- 0,05 \r\nLogiciel utilisé: Cura\r\nFormats de fichier acceptés: STL \r\nMatériaux utilisés: PLA (en stock).", slug: 'imprimante-3d'},
    {name: 'Petite Fraiseuse', description: "La fraiseuse numérique Roland Modela MDX-20\r\nInformations générales\r\nCette machine est utilisée  pour l'usinage et le scannage 3D de précision. Elle permet principalement d'usiner des circuits imprimés et des moules de petite taille. Le faible diamètre des fraises utilisées (Ø 0,3 mm à  Ø 6mm) induit que certains temps d'usinages peuvent êtres long (> 12h), c'est pourquoi cette fraiseuse peut être laissée en autonomie toute une nuit afin d'obtenir le plus précis des usinages au FabLab.\r\nMatériaux usinables:\r\nLes principaux matériaux usinables sont le bois, plâtre, résine, cire usinable, cuivre.\r\n", spec: "Taille du plateau X/Y : 220 mm x 160 mm\r\nVolume maximal de travail: 203,2 mm (X), 152,4 mm (Y), 60,5 mm (Z)\r\nPrécision usinage: 0,00625 mm\r\nPrécision scannage: réglable de 0,05 à 5 mm (axes X,Y) et 0,025 mm (axe Z)\r\nVitesse d'analyse (scannage): 4-15 mm/sec\r\n \r\n \r\nLogiciel utilisé pour le fraisage: Roland Modela player 4 \r\nLogiciel utilisé pour l'usinage de circuits imprimés: Cad.py (linux)\r\nFormats acceptés: STL,PNG 3D\r\nFormat d'exportation des données scannées: DXF, VRML, STL, 3DMF, IGES, Grayscale, Point Group et BMP\r\n", slug: 'petite-fraiseuse'},
    {name: 'FORM1+ imprimante 3D', description: "Form 1+, imprimante 3D stéréolithographie.\n\nLa photopolymérisation est le premier procédé de prototypage rapide à avoir été développé dans les années 1980. Le nom de SLA (pour StereoLithography Apparatus) lui a été donné. Il repose sur les propriétés qu'ont certaines résines à se polymériser sous l'effet de la lumière et de la chaleur. (Source : <a href=\"http://fr.wikipedia.org/wiki/St%C3%A9r%C3%A9olithographie\" target=\"_blank\"> wikipédia</a>)\n\n<i>Possibilité d'utiliser 3 résines de couleurs différentes au Lab : noir, blanc et translucide.</i>\n\n<a href=\"http://formlabs.com/fr/products/materials/standard/\" Title=\"http://formlabs.com/fr/products/materials/standard/\" target=\"_blank\">Plus d'infos sur le site web de Formlab</a>", spec: "Imprimante :\n- Dimensions : 30 × 28 × 45 cm\n- Poids : 8 kg\n- Température d'utilisation : 18–28° C\n- Alimentation : 100–240 V ; 1.5 A 50/60 Hz ; 60 W.\n\nCaractéristiques du laser :\n- EN 60825-1:2007 certifié\n- Class 1 Laser Product\n- 405nm violet laser\n\nPropriétés d'impression :\n- Technologie stéréolithographie (SLA)\n- Volume d'impression : 125 × 125 × 165 mm\n- Dimension minimale : 300 microns\n- Épaisseur des couches (Résolution verticale) : 25, 50, 100 microns\n- Ressources Générées automatiquement\n- Facilement amovible", slug: 'form1-imprimante-3d'}
  ])

  Price.all.each do |p|
    p.update_columns(amount: (rand()*50+5).floor*100)
  end
end

# if Plan.count == 0
#   Group.all.each do |group|
#     %w(month year).each do |interval|
#       Plan.create!(base_name: "plan #{SecureRandom.hex(4)}", amount: (rand()*200+50).floor*100, interval: interval, group: group)
#     end
#   end
# end

if Category.count == 0
  Category.create!([
    {name: 'Stage'},
    {name: 'Atelier'}
  ])
end

unless Setting.find_by(name: 'about_body').try(:value)
  setting = Setting.find_or_initialize_by(name: 'about_body')
  setting.value = "<p>Le Fab Lab de <a href=\"http://lacasemate.fr\" target=\"_blank\">La Casemate</a> est un"+
  ' atelier de fabrication numérique où l’on peut utiliser des machines de découpe, des imprimantes 3D,… permettant'+
  ' de travailler sur des matériaux variés : plastique, bois, carton, vinyle, … afin de créer toute sorte d’objet grâce'+
  ' à la conception assistée par ordinateur ou à l’électronique.  Mais le Fab Lab est aussi un lieu d’échange de'+
  ' compétences technique. </p>'+
  " <p>Le Fab Lab de <a href=\"http://lacasemate.fr\" target=\"_blank\">La Casemate</a> est un espace"+
  ' permanent : ouvert à tous, il offre la possibilité de réaliser des objets soi-même, de partager ses'+
  ' compétences et d’apprendre au contact des médiateurs du Fab Lab et des autres usagers. </p>'+
  '<p>La formation au Fab Lab s’appuie sur des projets et le partage de connaissances : vous devez prendre'+
  ' part à la capitalisation des connaissances et à l’instruction des autres utilisateurs.</p>'
  setting.save
end

unless Setting.find_by(name: 'about_title').try(:value)
  setting = Setting.find_or_initialize_by(name: 'about_title')
  setting.value = 'Imaginer, Fabriquer, <br>Partager au Fab Lab <br> de La Casemate'
  setting.save
end

unless Setting.find_by(name: 'about_contacts').try(:value)
  setting = Setting.find_or_initialize_by(name: 'about_contacts')
  setting.value = '<dl>'+
  '<dt>Manager Fab Lab :</dt>'+
  '<dd>jean-michel.molenaar@lacasemate.fr</dd>'+
  '  <dt>Responsable médiation :</dt>'+
  '  <dd>catherine.demarcq@lacasemate.fr</dd>'+
  '    <dt>Animateur scientifique :</dt>'+
  '    <dd>diego.scharager@lacasemate.fr</dd>'+
  '    </dl>'+
  '<br><br>'+
  "<p><a href='http://lacasemate.fr'>Visitez le site de La Casemate</a></p>"
  setting.save
end

unless Setting.find_by(name: 'twitter_name').try(:value)
  setting = Setting.find_or_initialize_by(name: 'twitter_name')
  setting.value = 'fablabgrenoble'
  setting.save
end

unless Setting.find_by(name: 'machine_explications_alert').try(:value)
  setting = Setting.find_or_initialize_by(name: 'machine_explications_alert')
  setting.value = "Tout achat d'heure machine est définitif. Aucune"+
  ' annulation ne pourra être effectuée, néanmoins au plus tard 24h avant le créneau fixé, vous pouvez en'+
  " modifier la date et l'horaire à votre convenance et en fonction du calendrier proposé. Passé ce délais,"+
  ' aucun changement ne pourra être effectué.'
  setting.save
end

unless Setting.find_by(name: 'training_explications_alert').try(:value)
  setting = Setting.find_or_initialize_by(name: 'training_explications_alert')
  setting.value = 'Toute réservation de formation est définitive.'+
  ' Aucune annulation ne pourra être effectuée, néanmoins au plus tard 24h avant le créneau fixé, vous pouvez'+
  " en modifier la date et l'horaire à votre convenance et en fonction du calendrier proposé. Passé ce délais,"+
  ' aucun changement ne pourra être effectué.'
  setting.save
end

unless Setting.find_by(name: 'subscription_explications_alert').try(:value)
  setting = Setting.find_or_initialize_by(name: 'subscription_explications_alert')
  setting.value = '<p><b>Règle sur la date de début des abonnements</b><br></p><ul><li>'+
  " <span style=\"font-size: 1.6rem; line-height: 2.4rem;\">Si vous êtes un nouvel utilisateur - i.e aucune "+
  " formation d'enregistrée sur le site - votre abonnement débutera à la date de réservation de votre première "+
  " formation.</span><br></li><li><span style=\"font-size: 1.6rem; line-height: 2.4rem;\">Si vous avez déjà une "+
  " formation ou plus de validée, votre abonnement débutera à la date de votre achat d'abonnement.</span></li>"+
  " </ul><p>Merci de bien prendre ses informations en compte, et merci de votre compréhension. L'équipe du Fab Lab.<br>"+
  ' </p><p></p>'
  setting.save
end

unless Setting.find_by(name: 'invoice_logo').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_logo')
  setting.value = 'iVBORw0KGgoAAAANSUhEUgAAAyAAAABNCAYAAABe8gBxAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA/RpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMy1jMDExIDY2LjE0NTY2MSwgMjAxMi8wMi8wNi0xNDo1NjoyNyAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtbG5zOmRjPSJodHRwOi8vcHVybC5vcmcvZGMvZWxlbWVudHMvMS4xLyIgeG1wTU06T3JpZ2luYWxEb2N1bWVudElEPSJ1dWlkOjVEMjA4OTI0OTNCRkRCMTE5MTRBODU5MEQzMTUwOEM4IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOjAzODFDRjYwMEE1RTExRTQ5NzJDRkFDOTI4MTJEOEM1IiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOjAzODFDRjVGMEE1RTExRTQ5NzJDRkFDOTI4MTJEOEM1IiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIElsbHVzdHJhdG9yIENTNCI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ1dWlkOjI2NzQ5N2UwLTgyODEtNDg4Ny1iOGZlLTExMzA0ODhhZjRhOCIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo3RDc4OUVFODZFRjBFMzEx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'
  setting.save
end

unless Setting.find_by(name: 'invoice_reference').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_reference')
  setting.value = 'YYMMmmmX[/VL]R[/A]'
  setting.save
end

unless Setting.find_by(name: 'invoice_code-active').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_code-active')
  setting.value = 'true'
  setting.save
end

unless Setting.find_by(name: 'invoice_code-value').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_code-value')
  setting.value = 'INMEDFABLAB'
  setting.save
end

unless Setting.find_by(name: 'invoice_order-nb').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_order-nb')
  setting.value = 'nnnnnn-MM-YY'
  setting.save
end

unless Setting.find_by(name: 'invoice_VAT-active').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_VAT-active')
  setting.value = 'false'
  setting.save
end

unless Setting.find_by(name: 'invoice_VAT-rate').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_VAT-rate')
  setting.value = '20.0'
  setting.save
end

unless Setting.find_by(name: 'invoice_text').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_text')
  setting.value = "Notre association n'est pas assujettie à la TVA"
  setting.save
end

unless Setting.find_by(name: 'invoice_legals').try(:value)
  setting = Setting.find_or_initialize_by(name: 'invoice_legals')
  setting.value = 'La Casemate<br/>'+
                  '2 Place St Laurent 38000 GRENOBLE France<br/>'+
                  'Tél. Administration : +33 4 76 44 88 80<br/>'+
                  'Fax. : +33 4 76 42 76 66<br/>'+
                  'SIRET : 317 270 593 00013 - APE 913 E'
  setting.save
end

unless Setting.find_by(name: 'booking_window_start').try(:value)
  setting = Setting.find_or_initialize_by(name: 'booking_window_start')
  setting.value = '1970-01-01 08:00:00'
  setting.save
end

unless Setting.find_by(name: 'booking_window_end').try(:value)
  setting = Setting.find_or_initialize_by(name: 'booking_window_end')
  setting.value = '1970-01-01 23:59:59'
  setting.save
end

unless Setting.find_by(name: 'booking_move_enable').try(:value)
  setting = Setting.find_or_initialize_by(name: 'booking_move_enable')
  setting.value = 'true'
  setting.save
end

unless Setting.find_by(name: 'booking_move_delay').try(:value)
  setting = Setting.find_or_initialize_by(name: 'booking_move_delay')
  setting.value = '24'
  setting.save
end

unless Setting.find_by(name: 'booking_cancel_enable').try(:value)
  setting = Setting.find_or_initialize_by(name: 'booking_cancel_enable')
  setting.value = 'false'
  setting.save
end

unless Setting.find_by(name: 'booking_cancel_delay').try(:value)
  setting = Setting.find_or_initialize_by(name: 'booking_cancel_delay')
  setting.value = '24'
  setting.save
end

unless Setting.find_by(name: 'main_color').try(:value)
  setting = Setting.find_or_initialize_by(name: 'main_color')
  setting.value = '#cb1117'
  setting.save
end

unless Setting.find_by(name: 'secondary_color').try(:value)
  setting = Setting.find_or_initialize_by(name: 'secondary_color')
  setting.value = '#ffdd00'
  setting.save
end

Stylesheet.build_sheet!

unless Setting.find_by(name: 'training_information_message').try(:value)
  setting = Setting.find_or_initialize_by(name: 'training_information_message')
  setting.value = "Avant de réserver une formation, nous vous conseillons de consulter nos offres d'abonnement qui"+
                  ' proposent des conditions avantageuses sur le prix des formations et les heures machines.'
  setting.save
end


unless Setting.find_by(name: 'fablab_name').try(:value)
  setting = Setting.find_or_initialize_by(name: 'fablab_name')
  setting.value = 'Fab Lab de La Casemate'
  setting.save
end

unless Setting.find_by(name: 'name_genre').try(:value)
  setting = Setting.find_or_initialize_by(name: 'name_genre')
  setting.value = 'male'
  setting.save
end


unless DatabaseProvider.count > 0
  db_provider = DatabaseProvider.new
  db_provider.save

  unless AuthProvider.find_by(providable_type: DatabaseProvider.name)
    provider = AuthProvider.new
    provider.name = 'Fablab'
    provider.providable = db_provider
    provider.status = 'active'
    provider.save
  end
end

unless Setting.find_by(name: 'reminder_enable').try(:value)
  setting = Setting.find_or_initialize_by(name: 'reminder_enable')
  setting.value = 'true'
  setting.save
end

unless Setting.find_by(name: 'reminder_delay').try(:value)
  setting = Setting.find_or_initialize_by(name: 'reminder_delay')
  setting.value = '24'
  setting.save
end

if StatisticCustomAggregation.count == 0
  # available reservations hours for machines
  machine_hours = StatisticType.find_by(key: 'hour', statistic_index_id: 2)

  available_hours = StatisticCustomAggregation.new({
                       statistic_type_id: machine_hours.id,
                       es_index: 'fablab',
                       es_type: 'availabilities',
                       field: 'available_hours',
                       query: '{"size":0, "aggregations":{"%{aggs_name}":{"sum":{"field":"bookable_hours"}}}, "query":{"bool":{"must":[{"range":{"start_at":{"gte":"%{start_date}", "lte":"%{end_date}"}}}, {"match":{"available_type":"machines"}}]}}}'
                    })
  available_hours.save!

  # available training tickets
  training_bookings = StatisticType.find_by(key: 'booking', statistic_index_id: 3)

  available_tickets = StatisticCustomAggregation.new({
                         statistic_type_id: training_bookings.id,
                         es_index: 'fablab',
                         es_type: 'availabilities',
                         field: 'available_tickets',
                         query: '{"size":0, "aggregations":{"%{aggs_name}":{"sum":{"field":"nb_total_places"}}}, "query":{"bool":{"must":[{"range":{"start_at":{"gte":"%{start_date}", "lte":"%{end_date}"}}}, {"match":{"available_type":"training"}}]}}}'
                      })
  available_tickets.save!
end

unless StatisticIndex.find_by(es_type_key: 'space')
  index = StatisticIndex.create!({es_type_key:'space', label:I18n.t('statistics.spaces')})
  StatisticType.create!([
    {statistic_index_id: index.id, key: 'booking', label:I18n.t('statistics.bookings'), graph: true, simple: true},
    {statistic_index_id: index.id, key: 'hour', label:I18n.t('statistics.hours_number'), graph: true, simple: false}
  ])
end