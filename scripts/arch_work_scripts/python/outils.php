<?php
	require_once('../../../lib/PageGenerator.php');
	$page = new PageGenerator("Dixons-2010", "");
	echo $page->getHeader();
?>
<div id="content">
	<div id="area1" class="aside">
		<?php echo $page->getPartial('left-nav'); ?>		
	</div>
	<div id="area2" class="main">
		<section>
			<header>
				<h1>Outils</h1>
			</header>	
			<nav>
				<ol id="nav-a">
					<li><a href="#section-1">Introduction</a></li>
					<li><a href="#section-2">Page Generator Exporter</a></li>
					<li><a href="#section-3">Image List Generator</a></li>
				</ol>
				<?php /*<ol id="nav-b">
					<li><a href="#section-4">Item 4</a></li>
					<li><a href="#section-5">Item 5</a></li>
				</ol> */ ?>
			</nav>
		</section>
		<section>		
				<h2 id="section-1">1. Introduction</h2>
				<p>Ces outils se trouvent dans le répertoire DSG/share/tools/ sur le dépôt SVN.</p>
				<h2 id="section-2">2. Page Generator Exporter</h2>
				<p>Cet outil permet d’exporter une partie du SVN (tout ce qui est dans le répertoire DSG) en fichiers statiques.</p>
		<p>
			L'outil se trouve à l'adresse suivante : <a href="http://172.17.11.165/svn/DSG/share/tools/exporter/">http://172.17.11.165/svn/DSG/share/tools/exporter/</a>.<br />
			Il est également possible de l’utiliser en local, mais le script peut être assez gourmand (cela dépend du nombre de pages à exporter).
		</p>
		<p>Pour faire de gros exports, il est recommandé d'utiliser les réglages suivants dans le fichier php.ini (réglages utilisés par le serveur) :</p>
		<pre class="prettyprint">max_execution_time = 180
memory_limit = 128M</pre>
		<p>L’export se fait en deux étapes.</p>
		<p>Premièrement, une page propose de sélectionner les pages à exporter. Il faut ensuite cliquer sur le bouton « Exporter » en bas de la page.</p>
		<p>Deuxièmement, la liste des pages exportées apparaît, avec un lien permettant de télécharger une archive (.zip).</p>
		<p>Un système de verrouillage basique a été ajouté, il se peut que vous voyiez apparaître le message « Export en cours, merci d'attendre quelques instants ».</p>
		<p>Cela signifie que quelqu’un est déjà en train d’exporter. Si ce n'est pas le cas, il est possible de réinitialiser le système de verrouillage, en cliquant sur le bouton « Forcer la réinitialisation ? ».
		<h2 id="section-3">3. Image List Generator</h2>
		<p>Cet outil permet de créer une page listant toutes les images (de style et de contenu) d'un site. Cela permet de repérer des images déjà existantes pour les réutiliser, de contrôler la bonne utilisation des images (style ou contenu), etc.</p>
		
		<p>Pour l'utiliser, vous devez disposer de Python 3, téléchargeable à l'adresse suivante : <a href="http://python.org/download/">http://python.org/download/</a>
		(au moment de l'écriture de ce document, <a href="http://python.org/ftp/python/3.1.1/python-3.1.1.msi">Python 3.1.1</a> est la plus récente version disponible pour Windows).</p>
		<p>L'installation est très simple, "Suivant-Suivant-Suivant-Terminé".</p>
		
		<p>
			Vous pourrez ensuite lancer le script (double-clic), qui se trouve dans <code>DSG/share/tools/image_list_generator/generator.py</code> dans le dépôt SVN.<br />
			Il vous sera demandé d'indiquer le répertoire du site dont les images doivent être listées (validez avec la touche entrée).<br />
			Un fichier (.html) sera alors créé dans le répertoire du script. En appuyant sur la touche "i", vous pourrez passer les images sur un fond sombre.
		</p>
		</section>	
	</div>

</div>


<?php echo $page->getFooter(); ?>