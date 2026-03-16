# categorize-videos-default.ps1
$HtmlFile = "deepseek_html_20260316_851acf (1).html"
$OutputFile = "index-categorized.html"

# Read the HTML file
$Html = Get-Content $HtmlFile -Raw

# First, update the sidebar to have empty categories section
$SidebarPattern = '(?s)(<h3 class="sidebar-subhead">Categories</h3>\s*).*?(?=\s*</aside>)'
$NewSidebar = '<h3 class="sidebar-subhead">Categories</h3>\n    <!-- Categories will be populated by JavaScript -->'
$Html = $Html -replace $SidebarPattern, $NewSidebar

# Add the categorization script before the closing </body> tag
$CategorizationScript = @"

  <script>
    // Categorization function - defines which videos go in which categories
    function getVideoCategory(title, vimeoId) {
      // Workflow Management series
      if (title.includes('Workflow Management') || 
          (parseInt(vimeoId) >= 1173730642 && parseInt(vimeoId) <= 1173730849)) {
        return 'Workflow Management';
      }
      // Product Dive series
      else if (title.includes('Product Dive')) {
        return 'Product Dive';
      }
      // EV & Sustainability
      else if (title.includes('EV') || title.includes('Electric') || 
               title.includes('Sustainability') || title.includes('EV Management') ||
               vimeoId === '1173729574' || vimeoId === '1173729994' || 
               vimeoId === '1173729958' || vimeoId === '1173729717' ||
               vimeoId === '1173729703' || vimeoId === '1173729498') {
        return 'EV & Sustainability';
      }
      // Reporting & Analytics
      else if (title.includes('Report') || title.includes('CO2') || 
               title.includes('Dashboard') || title.includes('Creating Reports') ||
               vimeoId === '1173729293' || vimeoId === '1173729464' || 
               vimeoId === '1173729339' || vimeoId === '1173730503') {
        return 'Reporting & Analytics';
      }
      // Setup & Configuration
      else if (title.includes('Configuration') || title.includes('Configuring') || 
               title.includes('Administration') || title.includes('Setup') ||
               title.includes('Device') || title.includes('Driver Terminal') ||
               vimeoId === '1173729543' || vimeoId === '1173729513' || 
               vimeoId === '1173729394' || vimeoId === '1173730206' ||
               vimeoId === '1173730244' || vimeoId === '1173730236' ||
               vimeoId === '1173730225' || vimeoId === '1173729259') {
        return 'Setup & Configuration';
      }
      // Default category
      else {
        return 'General Training';
      }
    }

    // Function to reorganize the page by categories (DEFAULT VIEW)
    function reorganizeByCategory() {
      const cards = Array.from(document.querySelectorAll('.card.is-playable'));
      
      // Group cards by category
      const categories = {};
      
      cards.forEach(card => {
        const title = card.dataset.title || '';
        const vimeoId = card.dataset.vimeoId;
        const category = getVideoCategory(title, vimeoId);
        
        card.dataset.category = category;
        
        if (!categories[category]) {
          categories[category] = [];
        }
        categories[category].push(card);
      });
      
      // Sort categories by name
      const sortedCategories = Object.keys(categories).sort();
      
      // Get the main element and remove all sections
      const main = document.querySelector('.main');
      const oldSections = main.querySelectorAll('.section');
      oldSections.forEach(section => section.remove());
      
      // Create new sections for each category
      sortedCategories.forEach(categoryName => {
        const videos = categories[categoryName];
        if (videos.length === 0) return;
        
        const section = document.createElement('section');
        section.className = 'section';
        section.id = categoryName.toLowerCase().replace(/[&\s]+/g, '-');
        
        const sectionHead = document.createElement('div');
        sectionHead.className = 'section-head';
        sectionHead.innerHTML = `
          <div>
            <p class="eyebrow">Category</p>
            <h2>${categoryName}</h2>
          </div>
          <p>${videos.length} videos</p>
        `;
        
        const grid = document.createElement('div');
        grid.className = 'grid';
        
        // Clone cards to avoid duplicate event listeners
        videos.forEach(card => {
          const clone = card.cloneNode(true);
          // Ensure the clone has the correct category data
          clone.dataset.category = categoryName;
          grid.appendChild(clone);
        });
        
        section.appendChild(sectionHead);
        section.appendChild(grid);
        main.appendChild(section);
      });
      
      // Update sidebar categories
      updateSidebarCategories(categories);
      
      // Reattach event listeners to all cards
      attachEventListeners();
      
      // Update URL hash to remove any existing hash
      if (window.location.hash) {
        history.pushState("", document.title, window.location.pathname);
      }
    }

    // Function to update sidebar with category links
    function updateSidebarCategories(categories) {
      const sidebar = document.querySelector('.sidebar');
      const categoryHeading = sidebar.querySelector('.sidebar-subhead:last-of-type');
      
      // Remove old category links (keep only the heading)
      let next = categoryHeading.nextElementSibling;
      while (next) {
        const toRemove = next;
        next = next.nextElementSibling;
        if (toRemove.tagName === 'A') {
          toRemove.remove();
        }
      }
      
      // Sort categories for sidebar
      const sortedCategories = Object.keys(categories).sort();
      
      // Add new category links
      sortedCategories.forEach(categoryName => {
        const count = categories[categoryName].length;
        if (count > 0) {
          const link = document.createElement('a');
          link.href = `#${categoryName.toLowerCase().replace(/[&\s]+/g, '-')}`;
          link.innerHTML = `${categoryName} <span>${count}</span>`;
          
          // Add click handler to scroll smoothly
          link.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = link.getAttribute('href').substring(1);
            const targetSection = document.getElementById(targetId);
            if (targetSection) {
              targetSection.scrollIntoView({ behavior: 'smooth' });
            }
          });
          
          categoryHeading.insertAdjacentElement('afterend', link);
        }
      });
    }

    // Function to attach event listeners to cards
    function attachEventListeners() {
      const modal = document.getElementById('videoModal');
      const iframe = document.getElementById('vimeoPlayer');
      
      function openModal(vimeoId) {
        if (!vimeoId) return;
        iframe.src = `https://player.vimeo.com/video/${vimeoId}?autoplay=1&badge=0&byline=0&portrait=0&title=0`;
        modal.classList.add('is-open');
        document.body.style.overflow = 'hidden';
      }
      
      document.querySelectorAll('.card.is-playable').forEach(card => {
        // Remove any existing listeners by cloning and replacing
        const newCard = card.cloneNode(true);
        card.parentNode.replaceChild(newCard, card);
        
        newCard.addEventListener('click', (e) => {
          if (e.target.closest('.action')) return;
          const vimeoId = newCard.dataset.vimeoId;
          if (vimeoId) openModal(vimeoId);
        });

        const playBtn = newCard.querySelector('.action');
        if (playBtn) {
          playBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            const vimeoId = newCard.dataset.vimeoId;
            if (vimeoId) openModal(vimeoId);
          });
        }
      });
    }

    // Initialize when page loads - THIS SETS CATEGORIES AS DEFAULT VIEW
    window.addEventListener('load', () => {
      // Small delay to ensure DOM is fully loaded
      setTimeout(() => {
        reorganizeByCategory();
      }, 100);
    });

    // Also run if DOMContentLoaded fires before load
    document.addEventListener('DOMContentLoaded', () => {
      setTimeout(() => {
        if (!document.querySelector('.section[id]')) {
          reorganizeByCategory();
        }
      }, 100);
    });
  </script>
"@

# Insert the script before </body>
$Html = $Html -replace '</body>', "$CategorizationScript`n</body>"

# Save the modified HTML
$Html | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "✅ Categorized HTML created: $OutputFile" -ForegroundColor Green
Write-Host "The page will now show videos grouped by category by default." -ForegroundColor Cyan