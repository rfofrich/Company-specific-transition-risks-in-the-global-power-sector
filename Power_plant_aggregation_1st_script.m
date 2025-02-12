%Asset value
%
%Created Aug 14 2024
%by Robert Fofrich Navarro
%
%Calculates corporate asset value and assigns values to power plant parent company
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FUEL = 1;% sets fuel %1 COAL,2 GAS, 3 OIL, 4 Combined
clearvars -except ii; close all

TJ_to_BTu = 1/(9.478*1e8);
Kg_CO2_to_t_C02 = 1/1000;
BTu_perKWh_to_BTu_perMWh = 1000;

max_marker_size = 3000;
min_marker_size = 200; 

PowerPlantFuel = ["Coal", "Gas"];
saveyear = 0;%saves decommission year; any other number loads decommission year
saveresults = 1;
randomsave = 1;%set to 1 to save MC randomization; zero value  loads MC randomization - section 11 only

%works with section 6
COUNTRY = 1; %1 United States, 3 china, 4 europe, 9 india


if FUEL <4
    CombineFuelTypeResults = 0;
elseif FUEL >3
    CombineFuelTypeResults = 1;
end

current_year = 2024;
cutoffyear = 2035;%follows the index for carbontaxyear vector
CarbonPrice = 2000;%$/tCO2
CarbonTaxYear = current_year:2100;%sets the year for which the carbon tax is at its maximum

[ Dateindx] = find(CarbonTaxYear == cutoffyear);

StartYear = 1900;
EndYear = current_year;
Year = StartYear:EndYear;

RetailtoWholesaleConversionFactor = 1;%assumption

%Median PowerPlant Costs and Life from IPCC AR5 WGIII
%(https://www.ipcc.ch/site/assets/uploads/2018/02/ipcc_wg3_ar5_annex-iii.pdf)
%Power plant life
 
interest_rate_construction = .05; % interest rate over the construction loan (set as 5%)
DiscountRate = .1; %rate used by IEA 2020 report, 7% is in a highly regulated market, and 10% is in an environment with high risks

mean_Life_coal = 40;
Variable_OM_coal = 3.4;% $/MWh
Fixed_OM_coal = 23*1000;% $/MW
Construction_period_coal = 6; 
Capital_costs_coal = 2200*1000;% $/MW
Fuel_costs_coal = 4.1/3.6; % $/MWh
alpha_coal = DiscountRate/(1-(1+DiscountRate).^-mean_Life_coal);% percent
eta_coal = .39;% percent
Investment_costs_coal = (Capital_costs_coal/mean_Life_coal)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_coal)));

mean_Life_gas = 30;
Variable_OM_gas = 3.2;% $/MWh
Fixed_OM_gas = 7*1000;% $/MW
Construction_period_gas = 4; 
Capital_costs_gas = 1100*1000;% $/MW
Fuel_costs_gas = 8.9*3.6; % $/MWh
alpha_gas = DiscountRate/(1-(1+DiscountRate).^-mean_Life_gas);% percent
eta_gas = .55;% percent
Investment_costs_gas = (Capital_costs_gas/mean_Life_gas)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_gas)));

%Power plant ranges
LifeTimeRange = 20:5:60; 
CapacityFactorRange = .25:.05:.75;
AnnualHours = 8760;

%plus/minus age
Age_span = 20;% Power plant age range

%plus/minus CF
CF_span = .25;% Power plant capacity factor range
if FUEL == 1
    years = 2021:(current_year + mean_Life_coal);
elseif FUEL == 2
    years = 2021:(current_year + mean_Life_gas);
end


Country = readcell('../Data/Countries.xlsx');
O_M_costs = readcell('../Data/O_M_costs_of_new_power_ US_by_technology 2020.xlsx');
Wholesale_Electricity_Costs_strings = readcell('../Data/PriceOfElectricity_Worldbank.xlsx');
Wholesale_Electricity_Costs = xlsread('../Data/PriceOfElectricity_Worldbank.xlsx');
Wholesale_Electricity_Costs = Wholesale_Electricity_Costs(2:end,7)*1000./100;%retrieves data and converts it from cents/KWh and to U.S. dollars/MWh

PowerPlantParentCompany = {};
PowerPlantCompanyOwnerStakePercentage = [];


for i = 2:length(Wholesale_Electricity_Costs_strings)
    Wholesale_Electricity_Costs_Country_strings{i-1,1} = upper(Wholesale_Electricity_Costs_strings{i,1});%converts lower case strings to upper case for strcmpi to work
end

for gentype = FUEL
        clear Plants

        if FUEL == 1
            power_company_info = readcell(['../Data/New_power_data/Global-' PowerPlantFuel{gentype} '-Plant-Tracker-April-2024-Supplement-Proposals-outside-of-China.xlsx'], 'Sheet', 'Parent_company');
            power_operating_info = readcell(['../Data/New_power_data/Global-' PowerPlantFuel{gentype} '-Plant-Tracker-April-2024-Supplement-Proposals-outside-of-China.xlsx'], 'Sheet', 'Units');
            power_operating_info = power_operating_info(2:end,1:12);
        elseif FUEL == 2
            power_company_info = readcell('../Data/New_power_data/Global-Oil-and-Gas-Plant-Tracker-GOGPT-February-2024-v4.xlsx', 'Sheet', 'Parent_company');
            power_operating_info = readcell('../Data/New_power_data/Global-Oil-and-Gas-Plant-Tracker-GOGPT-February-2024-v4.xlsx', 'Sheet', 'Units');
            power_operating_info = power_operating_info(2:end,1:12);
        end

        NamePlate = [];
        Plant_age = [];
        Capacity_factor = [];
        Annual_CO2 = [];
        Countries = [];
        Operating_status = [];
        Start_year = [];
        Planned_decommission = [];
        Heat_rate = [];
        Emission_factor =[];

        [numRows, numCols] = size(power_company_info);

        for row = 1:numRows
            for col = 1:numCols
                cellValue = power_company_info{row, col};
                
                % Ensure the cell value is a string
                if ischar(cellValue) || isstring(cellValue)
                    cellValue = string(cellValue);
        
                    % Skip blank cells
                    if isempty(cellValue) || all(isspace(cellValue))
                        continue;
                    end
                    
                    % Extract the string part
                    if contains(cellValue, '[')
                        stringPart = extractBefore(cellValue, '[');
                    else
                        stringPart = cellValue;
                    end
                    stringPart = strtrim(stringPart);
                    
                    % Check if there is a value part
                    if contains(cellValue, '[') && contains(cellValue, ']')
                        % Extract the numeric value part
                        try
                            valueStr = extractBetween(cellValue, '[', ']');
                            valueStr = strrep(valueStr{1}, '%', '');
                            value = str2double(valueStr);
                            if isnan(value)
                                error('Failed to convert value to numeric');
                            end
                        catch
                            % Handle errors in value extraction
                            disp(['Error extracting value from: ' cellValue]);
                            value = NaN; % Or assign a default value
                        end
                    else
                        % remove if ownership value isn't present
                        value = 0;
                    end

                    % Section ensures only operating and plants under construction are counted
                    PowerPlantParentCompany{end+1} = stringPart;
                    PowerPlantCompanyOwnerStakePercentage(end+1) = value;
                    NamePlate(end+1) = power_operating_info{row,2};
                    Start_year(end+1) = power_operating_info{row,4};
                    Plant_age(end+1) = power_operating_info{row,6};
                    Capacity_factor(end+1) = power_operating_info{row,7};
                    Annual_CO2(end+1) = power_operating_info{row,8};
                    Countries{end+1} = power_operating_info{row, 1};
                    Operating_status{end+1} = power_operating_info{row, 3};
                    Planned_decommission(end+1) = power_operating_info{row,5};
                    if FUEL == 1
                        Heat_rate(end+1) = (power_operating_info{row,11}*BTu_perKWh_to_BTu_perMWh);% converts from BTU/kWh to BTU/MWh
                        Emission_factor(end+1) = power_operating_info{row,12};% kg CO2/TJ
                    elseif FUEL == 2
                        Emission_factor(end+1) = power_operating_info{row,11};% tCO2 eq/MWh
                    end
                end
            end
        end

        PowerPlantParentCompanys = standardizeCompanyNames(cellstr(PowerPlantParentCompany));
        PowerPlantParentCompany = PowerPlantParentCompanys;

        Plant_age = current_year - Start_year;
        Plant_age(isnan(Plant_age) | Plant_age < 0) = 0; % Assumes underconstruction plants are immediately built to start counting these emissions towards stranded assets

        Plants = [NamePlate', Plant_age', Capacity_factor', Annual_CO2', PowerPlantCompanyOwnerStakePercentage'];
        Plants_string = [string(PowerPlantParentCompany'), string(Countries'),string(Operating_status')];

        for power_plant = 1:length(Plants)
            if strcmpi(Plants_string{power_plant, 3}, 'operating') || strcmpi(Plants_string{power_plant, 3}, 'construction')
                Plants(power_plant, :) = Plants(power_plant, :);
                if FUEL == 1
                    Heat_rate(power_plant) = Heat_rate(power_plant);
                end
                Emission_factor(power_plant) = Emission_factor(power_plant);
            else
                % Set the plant data to NaN if it's neither 'operating' nor 'construction'
                Plants(power_plant, :) = nan;
                Planned_decommission(power_plant) = nan;
                if FUEL == 1
                    Heat_rate(power_plant) = nan;
                end
                Emission_factor(power_plant) = nan;
            end
        end


        CapitalCosts_strings = readcell('../Data/Capital_costs_Data_Power_sectors.xlsx');
        CapitalCosts = xlsread('../Data/Capital_costs_Data_Power_sectors.xlsx');


        if gentype == 1

            CapitalCosts = CapitalCosts(4,4:end);
      
            MIN = round(nanmean(CapitalCosts)-nanmean(CapitalCosts)*.2);
            MAX = round(nanmean(CapitalCosts)+nanmean(CapitalCosts)*.2);
             for powerplant = 1:length(Plants)
                if Plants(powerplant,2) <=15
                    Plants(powerplant,6) = randi([MIN MAX])*1000;%$/MW
                elseif Plants(powerplant,2) > 15
                    Plants(powerplant,6) = 0;
                end
            end
           
            WholeSaleCostofElectricity = nan(length(Plants_string),40);%sets wholesale price of electricity
            for powerplant = 1:length(Plants_string)
                PowerPlant_country = Plants_string{powerplant, 2};
                for country = 1:length(Wholesale_Electricity_Costs_Country_strings)
                    Electricity_cost_country = Wholesale_Electricity_Costs_Country_strings{country, 1};
                    if strcmpi(PowerPlant_country, Electricity_cost_country)
                        WholeSaleCostofElectricity(powerplant,1:40) = [Wholesale_Electricity_Costs_strings{country, 11}];%Wholesale electricity $ cost per MWh (last column is averaged across years and converted to MWh from KWh)
                    end
                end
            end

            for powerplant = 1:length(Plants_string)
                if isnan(WholeSaleCostofElectricity(powerplant,1))
                    WholeSaleCostofElectricity(powerplant,1:40) = Wholesale_Electricity_Costs(end,1);%Wholesale electricity $ cost per MWh
                end
            end

           
            save('../Data/WholeSaleCostofElectricityCoal','WholeSaleCostofElectricity');
            FuelCosts = readmatrix(['../Data/CoalCosts2.xlsx']);%$ Cost of per unit fuel
            Fuel_strings = readcell('../Data/CoalCosts2.xlsx');
            Fuel_strings = Fuel_strings(:,1:2);



            for i = 2:length(FuelCosts)
                for j = 4:76
                    if isnan(FuelCosts(i,j)) && ~isnan(FuelCosts(i,j-1))
                        FuelCosts(i,j) = FuelCosts(i,j-1);
                    end
                end
            end


            oprcounter = 1;

            for i = 2:length(Fuel_strings)
                FuelCost_strings{oprcounter,1} = upper(Fuel_strings{i,1});
                oprcounter = oprcounter + 1;
            end

            F_Costs = nan(length(Plants_string),40);
            for powerplant = 1:length(Plants_string)
                for country = 1:length(FuelCost_strings)
                    if strcmpi(Plants_string{powerplant,2},FuelCost_strings{country,1})
                       F_Costs(powerplant,1:40) = FuelCosts(country,22:61);%Costs of fuel per short ton 
                    end
                end
            end

            for powerplant = 1:length(Plants_string)
                if isnan(F_Costs(powerplant,1))
                    F_Costs(powerplant,1:40) = FuelCosts(2,22:61);
                end
            end


            for powerplant = 1:length(Plants)
                Plants(powerplant,7) = 8.14;%conversion factor for short ton to MWh
            end


            for powerplant = 1:length(Plants)
                Plants(powerplant,8) = 40.79*1000;%O&M fixed costs per year $/MW
            end

            colorschemecategory = zeros(length(Plants),1);
            for region = 1:5
                if region == 1%OECD
                    CountryNames = {'Albania', 'Australia', 'Austria', 'Belgium', 'Bosnia-Herzegovina', 'Bulgaria', 'Canada',...
                        'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Guam', 'Hungary',...
                        'Iceland', 'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Montenegro', 'Netherlands', 'New Zealand',...
                        'Norway', 'Poland', 'Portugal', 'Puerto Rico', 'Romania', 'Serbia', 'Slovakia', 'Slovenia', 'Spain', 'Sweden', 'Switzerland', ...
                        'North Macedonia', 'Türkiye', 'United Kingdom', 'United States','ENGLAND & WALES','Scotland','Ireland'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 4;
                                if strcmpi(Plants_string{powerplant,2},'UNITED KINGDOM') || strcmpi(Plants_string{powerplant,2},'ENGLAND & WALES')...
                                        || strcmpi(Plants_string{powerplant,2},'SCOTLAND') || strcmpi(Plants_string{powerplant,2},'IRELAND')
                                    colorschemecategory(powerplant) = 4;
                                elseif strcmpi(Plants_string{powerplant,2},'United States') 
                                    colorschemecategory(powerplant) = 1;
                                elseif strcmpi(Plants_string{powerplant,2},'AUSTRALIA') || strcmpi(Plants_string{powerplant,2},'NEW ZEALAND')...
                                        || strcmpi(Plants_string{powerplant,2},'CANADA') 
                                    colorschemecategory(powerplant) = 8;
                                end
                            end
                        end
                    end
                elseif region == 2%REF
                    CountryNames = {'Armenia', 'Azerbaijan', 'Belarus', 'Georgia', 'Kazakhstan', 'Kyrgyzstan', 'Moldova', 'Russia', ...
                        'Tajikistan', 'Turkmenistan', 'Ukraine', 'Uzbekistan'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 7;
                            end
                        end
                    end
                elseif region == 3%Asia
                    CountryNames = {'Afghanistan', 'Bangladesh', 'Bhutan', 'Brunei', 'Cambodia', 'China', 'North Korea', 'Fiji', 'French Polynesia','India' ...
                        'Indonesia', 'Laos', 'Malaysia', 'Maldives', 'Micronesia', 'Mongolia', 'Myanmar', 'Nepal',' New Caledonia', 'Pakistan', 'Papua New Guinea',...
                        'Philippines', 'South Korea', 'Samoa', 'Singapore','JAPAN', 'Solomon Islands', 'Sri Lanka', 'Taiwan', 'Thailand', 'Timor-Leste', 'Vanuatu', 'Vietnam'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 6;
                                if strcmpi(Plants_string{powerplant,2},'CHINA')
                                    colorschemecategory(powerplant) = 3;
                                elseif strcmpi(Plants_string{powerplant,2},'INDIA')
                                    colorschemecategory(powerplant) = 9;    
                                end
                            end
                        end
                    end
                elseif region == 4%MAF
                    CountryNames = {'Algeria', 'Angola','Bahrain', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroon', 'Cape Verde', 'Central African Republic',...
                        'Chad', 'Comoros', 'Congo', 'Cote dIvoire', 'Congo', 'Djibouti', 'Egypt', 'Equatorial Guinea', 'Eritrea', 'Ethiopia', ...
                        'Gabon', 'Gambia', 'Ghana', 'Guinea', 'Guinea-Bissau', 'Iran', 'Iraq', 'Israel', 'Jordan', 'Kenya', 'Kuwait', 'Lebanon', 'Lesotho', 'Liberia', ...
                        'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius', 'Mayotte', 'Morocco', 'Mozambique', 'Namibia', 'Niger', 'Nigeria', 'Palestine', ...
                        'Oman', 'Qatar', 'Rwanda', 'Reunion', 'Saudi Arabia', 'Senegal', 'Sierra Leone', 'Somalia', 'South Africa', 'South Sudan', 'Sudan', 'Swaziland',...
                        'Syria', 'Togo', 'Tunisia', 'Uganda', 'United Arab Emirates', 'Tanzania', 'Western Sahara', 'Yemen', 'Zambia', 'Zimbabwe'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 5;
                            end
                        end
                    end  
                elseif region == 5%LAM
                    CountryNames = {'Argentina', 'Aruba', 'Bahamas', 'Barbados', 'Belize', 'Bolivia', 'Brazil', 'Chile', 'Colombia', 'Costa Rica', 'Cuba', 'Dominican Republic',...
                        'Ecuador', 'El Salvador', 'French Guiana', 'Grenada', 'Guadeloupe', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaica', 'Martinique', 'Mexico', 'Nicaragua',...
                        'Panama', 'Paraguay', 'Peru', 'Suriname', 'Trinidad and Tobago', 'United States Virgin Islands', 'Uruguay', 'Venezuela'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 2;
                            end
                        end
                    end  
                end
            end
                    
                        
                           
            colorschemecategoryCoal = colorschemecategory;
            save('../Data/Results/CoalColors','colorschemecategoryCoal');

            if saveresults == 1
                save('../Data/Results/Coal_Plants','Plants','Planned_decommission', 'Emission_factor', 'Heat_rate');
                save('../Data/Results/Coal_Plants_strings','Plants_string');
                save('../Data/Results/CoalCostbyCountry','F_Costs');
            end

        elseif gentype == 2
            CapitalCosts = CapitalCosts(7,4:end);
      
            MIN = round(nanmean(CapitalCosts)-nanmean(CapitalCosts)*.2);
            MAX = round(nanmean(CapitalCosts)+nanmean(CapitalCosts)*.2);
             for powerplant = 1:length(Plants)
                if Plants(powerplant,2) <=15
                    Plants(powerplant,6) = randi([MIN MAX])*1000;%$/MW
                elseif Plants(powerplant,2) > 15
                    Plants(powerplant,6) = 0;
                end
            end

            WholeSaleCostofElectricity = nan(length(Plants_string),40);%sets wholesale price of electricity
            for powerplant = 1:length(Plants_string)
                PowerPlant_country = Plants_string{powerplant, 2};
                for country = 2:length(Wholesale_Electricity_Costs_Country_strings)
                    Electricity_cost_country = Wholesale_Electricity_Costs_Country_strings{country, 1};
                    if strcmpi(PowerPlant_country, Electricity_cost_country)
                        WholeSaleCostofElectricity(powerplant,1:40) = [Wholesale_Electricity_Costs_strings{country, 11}];%Wholesale electricity $ cost per MWh (last column is averaged across years and converted to MWh from KWh)
                    end
                end
            end
            
            for powerplant = 1:length(Plants_string)
                if isnan(WholeSaleCostofElectricity(powerplant,1))
                    WholeSaleCostofElectricity(powerplant,1:40) = Wholesale_Electricity_Costs(end,1);%Wholesale electricity $ cost per MWh
                end
            end
            save('../Data/WholeSaleCostofElectricityGas','WholeSaleCostofElectricity');

            FuelCosts = xlsread('../Data/NaturalGasCosts.xlsx');
            Fuel_strings = readcell('../Data/NaturalGasCosts.xlsx');    

            F_Costs = nan(length(Plants_string),40);
            for powerplant = 1:length(Plants_string)
                for country = 1:length(Fuel_strings)
                    if strcmpi(Plants_string{powerplant,2},Fuel_strings{country,1})
                       F_Costs(powerplant,1:40) = FuelCosts(country,1);%Costs of fuel per short ton 
                    else
                        F_Costs(powerplant,1:40) = FuelCosts(end,1);%Costs of fuel per short ton 
                    end
                end
            end

            oprcounter = 1;
            
            for i = 1:length(Fuel_strings)-3
                FuelCost_strings{oprcounter,1} = upper(Fuel_strings{i,1});
                oprcounter = oprcounter + 1;
            end


            for powerplant = 1:length(Plants)
                Plants(powerplant,8) = 14.17*1000;%O&M fixed costs per year $/MW
            end

            Plants(Plants == 0) = FuelCosts(length(FuelCost_strings),1);%price per MWh

            for powerplant = 1:length(Plants)
                Plants(powerplant,7) = 1;%conversion factor for gas  to MWh
            end

            for powerplant = 1:length(Plants)
                Plants(powerplant,10) = 20*1000;%O&M fixed costs per year $/MW
            end
            
            colorschemecategory = zeros(length(Plants),1);
            for region = 1:5
                if region == 1%OECD
                    CountryNames = {'Albania', 'Australia', 'Austria', 'Belgium', 'Bosnia-Herzegovina', 'Bulgaria', 'Canada',...
                        'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Guam', 'Hungary',...
                        'Iceland', 'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Montenegro', 'Netherlands', 'New Zealand',...
                        'Norway', 'Poland', 'Portugal', 'Puerto Rico', 'Romania', 'Serbia', 'Slovakia', 'Slovenia', 'Spain', 'Sweden', 'Switzerland', ...
                        'North Macedonia', 'Türkiye', 'United Kingdom', 'United States','ENGLAND & WALES','Scotland','Ireland'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 4;
                                if strcmpi(Plants_string{powerplant,2},'UNITED KINGDOM') || strcmpi(Plants_string{powerplant,2},'ENGLAND & WALES')...
                                        || strcmpi(Plants_string{powerplant,2},'SCOTLAND') || strcmpi(Plants_string{powerplant,2},'IRELAND')
                                    colorschemecategory(powerplant) = 4;
                                elseif strcmpi(Plants_string{powerplant,2},'United States') 
                                    colorschemecategory(powerplant) = 1;
                                elseif strcmpi(Plants_string{powerplant,2},'AUSTRALIA') || strcmpi(Plants_string{powerplant,2},'NEW ZEALAND')...
                                        || strcmpi(Plants_string{powerplant,2},'CANADA') 
                                    colorschemecategory(powerplant) = 8;
                                end
                            end
                        end
                    end
                elseif region == 2%REF
                    CountryNames = {'Armenia', 'Azerbaijan', 'Belarus', 'Georgia', 'Kazakhstan', 'Kyrgyzstan', 'Moldova', 'Russia', ...
                        'Tajikistan', 'Turkmenistan', 'Ukraine', 'Uzbekistan'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 7;
                            end
                        end
                    end
                elseif region == 3%Asia
                    CountryNames = {'Afghanistan', 'Bangladesh', 'Bhutan', 'Brunei', 'Cambodia', 'China', 'North Korea', 'Fiji', 'French Polynesia','India' ...
                        'Indonesia', 'Laos', 'Malaysia', 'Maldives', 'Micronesia', 'Mongolia', 'Myanmar', 'Nepal',' New Caledonia', 'Pakistan', 'Papua New Guinea',...
                        'Philippines', 'South Korea', 'Samoa', 'Singapore','JAPAN', 'Solomon Islands', 'Sri Lanka', 'Taiwan', 'Thailand', 'Timor-Leste', 'Vanuatu', 'Vietnam'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 6;
                                if strcmpi(Plants_string{powerplant,2},'CHINA')
                                    colorschemecategory(powerplant) = 3;
                                elseif strcmpi(Plants_string{powerplant,2},'INDIA')
                                    colorschemecategory(powerplant) = 9;    
                                end
                            end
                        end
                    end
                elseif region == 4%MAF
                    CountryNames = {'Algeria', 'Angola','Bahrain', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroon', 'Cape Verde', 'Central African Republic',...
                        'Chad', 'Comoros', 'Congo', 'Cote dIvoire', 'Congo', 'Djibouti', 'Egypt', 'Equatorial Guinea', 'Eritrea', 'Ethiopia', ...
                        'Gabon', 'Gambia', 'Ghana', 'Guinea', 'Guinea-Bissau', 'Iran', 'Iraq', 'Israel', 'Jordan', 'Kenya', 'Kuwait', 'Lebanon', 'Lesotho', 'Liberia', ...
                        'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius', 'Mayotte', 'Morocco', 'Mozambique', 'Namibia', 'Niger', 'Nigeria', 'Palestine', ...
                        'Oman', 'Qatar', 'Rwanda', 'Reunion', 'Saudi Arabia', 'Senegal', 'Sierra Leone', 'Somalia', 'South Africa', 'South Sudan', 'Sudan', 'Swaziland',...
                        'Syria', 'Togo', 'Tunisia', 'Uganda', 'United Arab Emirates', 'Tanzania', 'Western Sahara', 'Yemen', 'Zambia', 'Zimbabwe'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 5;
                            end
                        end
                    end  
                elseif region == 5%LAM
                    CountryNames = {'Argentina', 'Aruba', 'Bahamas', 'Barbados', 'Belize', 'Bolivia', 'Brazil', 'Chile', 'Colombia', 'Costa Rica', 'Cuba', 'Dominican Republic',...
                        'Ecuador', 'El Salvador', 'French Guiana', 'Grenada', 'Guadeloupe', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaica', 'Martinique', 'Mexico', 'Nicaragua',...
                        'Panama', 'Paraguay', 'Peru', 'Suriname', 'Trinidad and Tobago', 'United States Virgin Islands', 'Uruguay', 'Venezuela'};
                    CountryNames = upper(CountryNames)';
                    for powerplant = 1:length(Plants)
                        for Names = 1:length(CountryNames)
                            if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                Plants(powerplant,12) = region;
                                colorschemecategory(powerplant) = 2;
                            end
                        end
                    end  
                end
            end
                                                   
          
            colorschemecategoryGas = colorschemecategory;
            save('../Data/Results/GasColors','colorschemecategoryGas');
            if saveresults == 1
                save('../Data/Results/Gas_Plants','Plants','Planned_decommission', 'Emission_factor');
                save('../Data/Results/Gas_Plants_strings','Plants_string');
            end
            save('../Data/Results/GasCostbyCountry','F_Costs');
        end
end%gentype
