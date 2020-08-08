-- phpMyAdmin SQL Dump
-- version 4.2.12deb2+deb8u2
-- http://www.phpmyadmin.net
--
-- Client :  localhost
-- Généré le :  Mar 24 Octobre 2017 à 20:35
-- Version du serveur :  5.5.57-0+deb8u1
-- Version de PHP :  5.6.30-0+deb8u1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Base de données :  `udemy_sql`
--

-- --------------------------------------------------------

--
-- Structure de la table `cinema`
--

CREATE TABLE IF NOT EXISTS `cinema` (
`cinema_id` int(11) NOT NULL,
  `name` varchar(255) COLLATE utf8_bin NOT NULL,
  `city` varchar(255) COLLATE utf8_bin NOT NULL,
  `number_rooms` int(11) NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Contenu de la table `cinema`
--

INSERT INTO `cinema` (`cinema_id`, `name`, `city`, `number_rooms`) VALUES
(3, 'CGR CINÉMAS', 'Bordeaux', 10),
(4, 'CGR CINÉMAS', 'Evry', 8),
(5, 'CGR CINÉMAS', 'La Rochelle', 6),
(6, 'CGR CINÉMAS', 'Clermont-Ferrand', 7),
(7, 'CGR CINÉMAS', 'Troyes', 5),
(8, 'CGR CINÉMAS', 'Colmar', 6),
(9, 'CGR CINÉMAS', 'Auxerre', 4),
(10, 'CGR CINÉMAS', 'Narbonne', 5),
(13, 'MÉGARAMA', 'Boulogne sur Mer', 5),
(14, 'MÉGARAMA', 'Bordeaux', 9),
(15, 'MÉGARAMA', 'Montpellier', 7),
(16, 'MÉGARAMA', 'Quimper', 4),
(17, 'MÉGARAMA', 'Besançon', 6),
(18, 'MÉGARAMA', 'Audincourt', 4);

-- --------------------------------------------------------

--
-- Structure de la table `diffusion`
--

CREATE TABLE IF NOT EXISTS `diffusion` (
`diffusion_id` int(11) NOT NULL,
  `datetime` datetime NOT NULL,
  `cinema_id` int(11) NOT NULL,
  `room_id` int(11) NOT NULL,
  `film_id` int(11) NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Contenu de la table `diffusion`
--

INSERT INTO `diffusion` (`diffusion_id`, `datetime`, `cinema_id`, `room_id`, `film_id`) VALUES
(1, '2017-10-01 11:30:00', 3, 1, 3),
(2, '2017-10-01 12:00:00', 3, 2, 4),
(3, '2017-10-01 12:30:00', 3, 3, 9),
(4, '2017-10-01 13:00:00', 3, 4, 8),
(5, '2017-10-01 13:30:00', 3, 5, 6),
(6, '2017-10-01 14:00:00', 3, 6, 10),
(7, '2017-10-01 14:30:00', 3, 7, 5),
(8, '2017-10-01 15:00:00', 3, 8, 1),
(9, '2017-10-01 15:30:00', 3, 9, 2),
(10, '2017-10-01 16:00:00', 3, 10, 7);

-- --------------------------------------------------------

--
-- Structure de la table `film`
--

CREATE TABLE IF NOT EXISTS `film` (
`film_id` int(11) NOT NULL,
  `name` varchar(255) COLLATE utf8_bin NOT NULL,
  `distributor` varchar(255) COLLATE utf8_bin NOT NULL,
  `running_time` int(11) NOT NULL,
  `budget` int(11) NOT NULL,
  `language_id` int(11) NOT NULL,
  `original_language_id` int(11) NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Contenu de la table `film`
--

INSERT INTO `film` (`film_id`, `name`, `distributor`, `running_time`, `budget`, `language_id`, `original_language_id`) VALUES
(1, 'Forrest Gump', 'United International Pictures', 140, 55000000, 2, 1),
(2, 'La Ligne verte', 'United International Pictures', 189, 60000000, 2, 1),
(3, 'Your Name', 'Eurozoom', 109, 0, 2, 9),
(4, 'Lion', 'SDN', 118, 0, 2, 1),
(5, 'Tu ne tueras point', 'Metropolitan FilmExport', 140, 40000000, 2, 1),
(6, 'La Liste de Schindler', 'United International Pictures', 195, 25000000, 2, 1),
(7, 'Django Unchained', 'Sony Pictures Releasing France', 164, 100000000, 2, 1),
(8, 'Le Parrain', 'Paramount Pictures', 175, 6000000, 2, 1),
(9, '12 hommes en colère', 'Carlotta Films', 95, 340000, 2, 1),
(10, 'Gran Torino', 'Warner Bros. France', 111, 33000000, 2, 1);

-- --------------------------------------------------------

--
-- Structure de la table `language`
--

CREATE TABLE IF NOT EXISTS `language` (
`language_id` int(11) NOT NULL,
  `name` varchar(255) COLLATE utf8_bin NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Contenu de la table `language`
--

INSERT INTO `language` (`language_id`, `name`) VALUES
(1, 'English'),
(2, 'French'),
(3, 'Arabic'),
(4, 'Spanish'),
(5, 'Portuguese'),
(6, 'Russian'),
(7, 'German'),
(8, 'Italian'),
(9, 'Japanese'),
(10, 'Chinese'),
(11, 'Korean');

-- --------------------------------------------------------

--
-- Structure de la table `room`
--

CREATE TABLE IF NOT EXISTS `room` (
`room_id` int(11) NOT NULL,
  `name` varchar(255) COLLATE utf8_bin NOT NULL,
  `number_places` int(11) NOT NULL,
  `cinema_id` int(11) NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=91 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Contenu de la table `room`
--

INSERT INTO `room` (`room_id`, `name`, `number_places`, `cinema_id`) VALUES
(1, 'A', 100, 3),
(2, 'B', 60, 3),
(3, 'C', 70, 3),
(4, 'D', 70, 3),
(5, 'E', 70, 3),
(6, 'F', 60, 3),
(7, 'G', 70, 3),
(8, 'H', 70, 3),
(9, 'I', 50, 3),
(10, 'J', 70, 3),
(15, 'A', 65, 14),
(16, 'B', 65, 14),
(17, 'C', 65, 14),
(18, 'D', 65, 14),
(19, 'E', 65, 14),
(20, 'F', 65, 14),
(21, 'G', 65, 14),
(22, 'H', 65, 14),
(23, 'I', 65, 14),
(24, 'A', 75, 4),
(25, 'B', 75, 4),
(26, 'C', 75, 4),
(27, 'D', 75, 4),
(28, 'E', 75, 4),
(29, 'F', 75, 4),
(30, 'G', 75, 4),
(31, 'H', 75, 4),
(32, 'A', 65, 6),
(33, 'B', 65, 6),
(34, 'C', 65, 6),
(35, 'D', 65, 6),
(36, 'E', 65, 6),
(37, 'F', 65, 6),
(38, 'G', 65, 6),
(39, 'A', 60, 15),
(40, 'B', 60, 15),
(41, 'C', 60, 15),
(42, 'D', 60, 15),
(43, 'E', 60, 15),
(44, 'F', 60, 15),
(45, 'G', 60, 15),
(46, 'A', 50, 5),
(47, 'B', 50, 5),
(48, 'C', 50, 5),
(49, 'D', 50, 5),
(50, 'E', 50, 5),
(51, 'F', 50, 5),
(52, 'A', 50, 8),
(53, 'B', 50, 8),
(54, 'C', 50, 8),
(55, 'D', 50, 8),
(56, 'E', 50, 8),
(57, 'F', 50, 8),
(58, 'A', 45, 17),
(59, 'B', 45, 17),
(60, 'C', 45, 17),
(61, 'D', 45, 17),
(62, 'E', 45, 17),
(63, 'F', 45, 17),
(64, 'A', 50, 7),
(65, 'B', 50, 7),
(66, 'C', 50, 7),
(67, 'D', 50, 7),
(68, 'E', 50, 7),
(69, 'A', 55, 10),
(70, 'B', 55, 10),
(71, 'C', 55, 10),
(72, 'D', 55, 10),
(73, 'E', 55, 10),
(74, 'A', 50, 13),
(75, 'B', 50, 13),
(76, 'C', 50, 13),
(77, 'D', 50, 13),
(78, 'E', 50, 13),
(79, 'A', 40, 9),
(80, 'B', 40, 9),
(81, 'C', 40, 9),
(82, 'D', 40, 9),
(83, 'A', 45, 16),
(84, 'B', 45, 16),
(85, 'C', 45, 16),
(86, 'D', 45, 16),
(87, 'A', 40, 18),
(88, 'B', 40, 18),
(89, 'C', 45, 18),
(90, 'D', 45, 18);

--
-- Index pour les tables exportées
--

--
-- Index pour la table `cinema`
--
ALTER TABLE `cinema`
 ADD PRIMARY KEY (`cinema_id`);

--
-- Index pour la table `diffusion`
--
ALTER TABLE `diffusion`
 ADD PRIMARY KEY (`diffusion_id`);

--
-- Index pour la table `film`
--
ALTER TABLE `film`
 ADD PRIMARY KEY (`film_id`);

--
-- Index pour la table `language`
--
ALTER TABLE `language`
 ADD PRIMARY KEY (`language_id`);

--
-- Index pour la table `room`
--
ALTER TABLE `room`
 ADD PRIMARY KEY (`room_id`);

--
-- AUTO_INCREMENT pour les tables exportées
--

--
-- AUTO_INCREMENT pour la table `cinema`
--
ALTER TABLE `cinema`
MODIFY `cinema_id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=19;
--
-- AUTO_INCREMENT pour la table `diffusion`
--
ALTER TABLE `diffusion`
MODIFY `diffusion_id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=11;
--
-- AUTO_INCREMENT pour la table `film`
--
ALTER TABLE `film`
MODIFY `film_id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=11;
--
-- AUTO_INCREMENT pour la table `language`
--
ALTER TABLE `language`
MODIFY `language_id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=12;
--
-- AUTO_INCREMENT pour la table `room`
--
ALTER TABLE `room`
MODIFY `room_id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=91;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
